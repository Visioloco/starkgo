const express = require('express');
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const fs = require('fs');
const { execSync } = require('child_process');
const app = express();
// `verify` guarda el body CRUDO: la firma del webhook de Rapid se calcula
// sobre los bytes exactos que envía el servidor, no sobre el JSON re-armado.
app.use(
  express.json({
    limit: '10mb',
    verify: (req, res, buf) => {
      req.rawBody = buf;
    },
  })
);
// ePayco notifica por `application/x-www-form-urlencoded` (igual que la
// mayoría de pasarelas colombianas), así que hay que parsear ese formato.
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
const colas = {};

// ═══════════════════════════════════════════════════════════
//  CREDENCIALES — NUNCA en el código ni en git (el repo es público)
//  Prioridad: 1) variable de entorno  (ej. export RAPID_ACCESS_KEY=...)
//             2) functions/credenciales.local.json  (está en .gitignore)
//  Ver `credenciales.local.ejemplo.json` para el formato.
// ═══════════════════════════════════════════════════════════
function cargarCredencialesLocales() {
  try {
    const creds = require('./credenciales.local.json');
    console.log('[CONFIG] credenciales.local.json cargado');
    return creds && typeof creds === 'object' ? creds : {};
  } catch (e) {
    // No existe el archivo: se usan las variables de entorno.
    return {};
  }
}
const CREDENCIALES_LOCALES = cargarCredencialesLocales();

// Devuelve la credencial desde el entorno o desde el JSON local.
function credencial(nombre) {
  return String(process.env[nombre] || CREDENCIALES_LOCALES[nombre] || '').trim();
}

let historial = [];
let apikeysValidas = new Set();
let ultimaActualizacion = 0;
let ultimoRefrescoForzado = 0;
const CACHE_MS = 5 * 60 * 1000;
// Si llega una apikey que NO está en el cache, se fuerza un refresco (como
// máximo uno cada REFRESCO_MIN_MS) para no rechazar claves nuevas.
const REFRESCO_MIN_MS = 10 * 1000;
// ─────────────────────────────────────────────────────────────
//  ENTREGA CONFIRMADA DE LA COLA (Simple Queues / bindings / PPPoE)
//
//  ANTES: /cola vaciaba la cola apenas el MikroTik la DESCARGABA. Si el
//  /import fallaba (una sola línea con error corta TODO el archivo) los
//  comandos se perdían para siempre → la Simple Queue y el ip-binding
//  nunca se creaban y no había forma de enterarse.
//
//  AHORA: el lote queda "en vuelo" y sólo se borra cuando el MikroTik
//  confirma con GET /cola/ack. La línea de confirmación va SIEMPRE al
//  final del .rsc: si el /import se corta antes, no hay ack y el VPS
//  reenvía el lote completo en el próximo ciclo. Como todos los comandos
//  son idempotentes, reenviarlos no rompe nada.
// ─────────────────────────────────────────────────────────────
const enVuelo = {};            // apikey → { token, cmds, enviadoEn }
const ultimaConfirmacion = {}; // apikey → timestamp (ms) del último ack
// Si el MikroTik no confirma en este plazo, el lote se re-encola y se
// reenvía. Debe ser mayor que el intervalo del scheduler (1-5 min).
const COLA_TTL_MS = Number(process.env.COLA_TTL_MS || 10 * 60 * 1000);

// ═══════════════════════════════════════════════════════════
//  SANITIZADO DE VALORES RouterOS
//  Un nombre con comillas, "$", ";" o un salto de línea rompía el
//  /import COMPLETO en el MikroTik. Todos los valores que se
//  interpolan en un comando pasan por acá.
// ═══════════════════════════════════════════════════════════

// Texto seguro para name=/comment= (sin comillas ni $ ni saltos).
function _ros(valor, max = 64) {
  return String(valor == null ? '' : valor)
    .replace(/[\r\n]+/g, ' ')
    .replace(/["$;\\`{}]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, max);
}

// IPv4 válida o '' (nunca se mete basura en target=/address=).
function _rosIp(ip) {
  const s = String(ip == null ? '' : ip).trim();
  return /^(\d{1,3}\.){3}\d{1,3}$/.test(s) ? s : '';
}

// MAC válida normalizada (AA:BB:CC:DD:EE:FF) o ''.
// Acepta cualquier separador (- . : espacio) porque el MikroTik las muestra
// distinto según la pantalla: se normaliza antes de meterla en un comando.
function _rosMac(mac) {
  const s = String(mac == null ? '' : mac).trim().toUpperCase().replace(/[^0-9A-F]/g, '');
  if (s.length !== 12) return '';
  return s.match(/.{2}/g).join(':');
}

// Velocidad RouterOS válida (ej: 5M, 10M, 1.5M, 768k) o null.
function _rosRate(v) {
  const s = String(v == null ? '' : v).trim();
  return /^[0-9]+(\.[0-9]+)?[kKmMgG]?$/.test(s) ? s : null;
}


// Recarga el set de apikeys válidas desde `config_mikrotik.vpsApiKey`.
async function refrescarApikeys() {
  try {
    const snap = await db.collection('config_mikrotik').get();
    apikeysValidas = new Set(snap.docs.map(d => d.data().vpsApiKey).filter(Boolean));
    ultimaActualizacion = Date.now();
    console.log(`[Auth] ${apikeysValidas.size} apikeys validas en cache`);
    return true;
  } catch (e) {
    console.error('[Auth] Error actualizando cache:', e.message);
    return false;
  }
}

// Valida la apikey contra el cache de `config_mikrotik.vpsApiKey`.
//
// IMPORTANTE: antes, si la apikey no estaba en el cache se esperaba hasta 5
// minutos (CACHE_MS) para refrescar → la app mostraba "No autorizado" al
// registrar el peer del MikroTik justo después de generar/rotar la API Key.
// Ahora, ante un MISS se refresca enseguida (con tope de 1 refresco cada
// 10 s para no golpear Firestore con claves inválidas).
async function validarApikey(apikey) {
  if (!apikey) return false;
  if (apikeysValidas.has(apikey)) return true;
  const ahora = Date.now();
  const vencida = ahora - ultimaActualizacion > CACHE_MS;
  const puedeForzar = ahora - ultimoRefrescoForzado > REFRESCO_MIN_MS;
  if (vencida || puedeForzar) {
    ultimoRefrescoForzado = ahora;
    await refrescarApikeys();
  }
  return apikeysValidas.has(apikey);
}

function encolar(apikey, cmd) {
  if (!colas[apikey]) colas[apikey] = [];
  const ip = String(cmd.ip || '');
  const mac = String(cmd.mac || '');
  const yaEsta = colas[apikey].some(
    (c) =>
      c.nombre === cmd.nombre &&
      c.accion === cmd.accion &&
      String(c.ip || '') === ip &&
      String(c.mac || '') === mac
  );
  if (!yaEsta) colas[apikey].push({ ...cmd, fecha: new Date() });
}

// Construye target/max-limit + ráfagas (burst) de una Simple Queue.
// Los valores de ráfaga llegan opcionales desde /limitar y se validan con un
// patrón estricto para no inyectar comandos extra al RouterOS.
function _colaBaseQueue(c) {
  const rateVal = _rosRate;
  const tiempoVal = /^\d{1,3}$/.test(String(c.tiempo || '')) ? String(c.tiempo) : null;
  // ── ORDEN DE LA VELOCIDAD (compatibilidad app vieja / nueva) ──
  // RouterOS escribe `max-limit` (y `burst-limit`) como SUBIDA/BAJADA
  // (upload/download desde el punto de vista del cliente).
  //   · App NUEVA → manda `ordenVelocidad: 'subida-bajada'` y sus campos
  //     `subida`/`bajada` con el significado real.
  //   · App VIEJA (todavía instalada en algún teléfono) → NO manda el campo y
  //     además mandaba los valores INVERTIDOS (su `bajada` traía la subida).
  //     Se respeta ese orden para que no se den vuelta los megas mientras se
  //     actualiza la APK.
  const ordenNuevo = String(c.ordenVelocidad || '') === 'subida-bajada';
  const subida = rateVal(ordenNuevo ? c.subida : c.bajada) || '1M';
  const bajada = rateVal(ordenNuevo ? c.bajada : c.subida) || subida;
  // IMPORTANTE: el orden de la ráfaga coincide con el max-limit de la app
  // (primero el valor SUBIDA de la velocidad). Ej: burst-limit=2M/6M.
  const bB = rateVal(c.burstSubida);
  const bS = rateVal(c.burstBajada);
  const uB = rateVal(c.umbralSubida);
  const uS = rateVal(c.umbralBajada);
  const burst =
    bB && bS && uB && uS && tiempoVal
      ? ` burst-limit=${bB}/${bS} burst-threshold=${uB}/${uS} burst-time=${tiempoVal}`
      : '';
  return `target=${_rosIp(c.ip)}/32 max-limit=${subida}/${bajada}${burst}`;
}

// Convierte el lote pendiente en comandos RouterOS IDEMPOTENTES.
// Idempotente = se puede reenviar sin efectos secundarios: los reintentos
// de /cola no duplican address-list, bindings ni Simple Queues.
function construirComandos(pendientes) {
  return (pendientes || [])
    .map((c) => {
      const nombre = _ros(c.nombre || c.usuario);
      const ip = _rosIp(c.ip);
      if (c.accion === 'bloquear') {
        if (!ip) return '';
        return `:if ([:len [/ip firewall address-list find where address="${ip}" and list="morosos"]] = 0) do={ /ip firewall address-list add list=morosos address="${ip}" comment="${nombre}" }`;
      }
      if (c.accion === 'desbloquear') {
        const buscar = ip ? `address="${ip}"` : (nombre ? `comment="${nombre}"` : '');
        if (!buscar) return '';
        return `:if ([:len [/ip firewall address-list find where ${buscar}]] > 0) do={ /ip firewall address-list remove [find where ${buscar}] }`;
      }
      // Portal de pago para morosos: quitamos el "bypass" del hotspot para que
      // esa IP quede cautiva (ve el login/portal). Si no existe binding, no hace nada.
      if (c.accion === 'hotspot-bloquear') {
        const buscar = ip ? `address="${ip}"` : (nombre ? `comment="StarkGo ${nombre}"` : '');
        if (!buscar) return '';
        const quitarBinding = `:if ([:len [/ip hotspot ip-binding find where ${buscar}]] > 0) do={ /ip hotspot ip-binding remove [find where ${buscar}] }`;
        // Si el cliente tenía una sesión de hotspot YA autenticada (ficha o
        // login en el portal), la cortamos para que el corte y el portal
        // cautivo sean inmediatos y no espere a que caduque la sesión.
        if (!ip) return quitarBinding;
        const cortarSesion = `:if ([:len [/ip hotspot active find where address="${ip}"]] > 0) do={ /ip hotspot active remove [find where address="${ip}"] }`;
        return `${quitarBinding}\r\n${cortarSesion}`;
      }
      // Portal de pago: al reactivar el cliente le restauramos el bypass para que
      // navegue normal sin pasar por el portal.
      if (c.accion === 'hotspot-desbloquear') {
        if (!ip) return '';
        return `:if ([:len [/ip hotspot ip-binding find where address="${ip}"]] = 0) do={ /ip hotspot ip-binding add address="${ip}" type=bypassed comment="StarkGo ${nombre}" }`;
      }
      // 🛡️ BLINDAJE DEL ADMINISTRADOR (mi teléfono).
      // Mientras creás fichas o configurás el hotspot, tu equipo queda
      // "bypassed": el portal cautivo NO le pide ficha/PIN y podés seguir
      // trabajando sin loguearte. Acepta IP y/o MAC:
      //   · con MAC el blindaje sobrevive a los cambios de IP del DHCP,
      //   · con IP funciona igual (útil si el celular tiene MAC aleatoria).
      // Además queda en la address-list `starkgo_admin` para auditoría/reglas.
      if (c.accion === 'hotspot-blindar-admin') {
        const mac = _rosMac(c.mac);
        if (!ip && !mac) return '';
        const quien = nombre || 'admin';
        const attrs = [ip ? `address="${ip}"` : '', mac ? `mac-address="${mac}"` : '']
          .filter(Boolean)
          .join(' ');
        const buscar = mac ? `mac-address="${mac}"` : `address="${ip}"`;
        const lineas = [
          `:if ([:len [/ip hotspot ip-binding find where ${buscar}]] = 0) do={ /ip hotspot ip-binding add ${attrs} type=bypassed comment="StarkGo ADMIN ${quien}" }`,
        ];
        if (ip) {
          lineas.push(
            `:if ([:len [/ip firewall address-list find where address="${ip}" and list="starkgo_admin"]] = 0) do={ /ip firewall address-list add list=starkgo_admin address="${ip}" comment="StarkGo ADMIN ${quien}" }`
          );
        }
        return lineas.join('\r\n');
      }
      // 📌 MARCAR EL LEASE (DHCP) DE UN CLIENTE.
      // Deja la IP de la antena: ESTÁTICA (así el DHCP no se la cambia),
      // con comentario `StarkGo <cliente>` y en la address-list `starkgo`.
      // Todo en UNA línea: el /import del MikroTik se corta si una línea falla.
      // Idempotente: si ya es estática no la vuelve a convertir, y si la IP ya
      // está en la lista no la duplica.
      if (c.accion === 'marcarLease') {
        if (!ip) return '';
        const quien = nombre || 'cliente';
        const buscarLease =
          `:local lid [/ip dhcp-server lease find where address="${ip}"]; ` +
          `:if ([:len $lid] > 0) do={ ` +
          `:if ([:tostr [/ip dhcp-server lease get $lid dynamic]] = "true") do={ /ip dhcp-server lease make-static $lid }; ` +
          `/ip dhcp-server lease set $lid comment="StarkGo ${quien}" }`;
        const enLista =
          `:if ([:len [/ip firewall address-list find where address="${ip}" and list="starkgo"]] = 0) do={ ` +
          `/ip firewall address-list add list=starkgo address="${ip}" comment="StarkGo ${quien}" }`;
        return `${buscarLease}\r\n${enLista}`;
      }
      // Simple Queue por IP de antena (nombre = cliente). Idempotente:
      // si ya existe la actualiza, si no la crea.
      if (c.accion === 'limitarMegas') {
        if (!ip || !nombre) return '';
        const base = _colaBaseQueue(c);
        return `:if ([:len [/queue simple find name="${nombre}"]] > 0) do={ /queue simple set [find name="${nombre}"] ${base} } else={ /queue simple add name="${nombre}" ${base} }`;
      }
      if (c.accion === 'pppoeCrear') {
        const usuario = _ros(c.usuario, 64);
        const perfil = _ros(c.perfil, 64) || `starkgo_${usuario}`;
        const clave = _ros(c.clave, 64);
        const subidaP = _rosRate(c.subida) || '1M';
        const bajadaP = _rosRate(c.bajada) || subidaP;
        if (!usuario || !clave) return '';
        const crearSecreto = `:if ([:len [/ppp secret find name="${usuario}"]] > 0) do={ /ppp secret set [find name="${usuario}"] password="${clave}" profile="${perfil}" comment="${nombre}" } else={ /ppp secret add name="${usuario}" password="${clave}" service=pppoe profile="${perfil}" comment="${nombre}" }`;
        const crearPerfil = `:if ([:len [/ppp profile find name="${perfil}"]] > 0) do={ /ppp profile set [find name="${perfil}"] rate-limit="${subidaP}/${bajadaP}" } else={ /ppp profile add name="${perfil}" rate-limit="${subidaP}/${bajadaP}" local-address=192.168.100.1 remote-address=pool-pppoe }`;
        return `${crearPerfil}\r\n${crearSecreto}`;
      }
      if (c.accion === 'pppoeEliminar') {
        const usuario = _ros(c.usuario, 64);
        if (!usuario) return '';
        return `:if ([:len [/ppp secret find name="${usuario}"]] > 0) do={ /ppp secret remove [find name="${usuario}"] }`;
      }
      return '';
    })
    .filter(Boolean)
    .join('\r\n');
}

// GET /cola → entrega el lote en vuelo (o el nuevo) + la línea de confirmación.
app.get('/cola', async (req, res) => {
  const { apikey } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).send('');

  const ahora = Date.now();
  let lote = enVuelo[apikey] || null;

  // Lote viejo sin confirmar = el /import del MikroTik NO terminó:
  // lo devolvemos a la cola pendiente para no perder los comandos.
  if (lote && ahora - lote.enviadoEn > COLA_TTL_MS) {
    console.log(`[COLA] ${String(apikey).substring(0, 12)} sin confirmar → reintento`);
    colas[apikey] = [...(colas[apikey] || []), ...lote.cmds];
    delete enVuelo[apikey];
    lote = null;
  }

  // Tomamos TODO lo pendiente como un único lote en vuelo.
  if (!lote && (colas[apikey] || []).length > 0) {
    lote = {
      token: `${ahora}x${Math.random().toString(36).slice(2, 8)}`,
      cmds: colas[apikey].splice(0),
      enviadoEn: ahora,
    };
    enVuelo[apikey] = lote;
  }

  // Si entró algo NUEVO mientras el lote estaba en vuelo, se suma al mismo
  // lote: así no tiene que esperar un ciclo entero para llegar al router.
  // (Los comandos son idempotentes, reenviarlos es inofensivo.)
  if (lote && (colas[apikey] || []).length > 0) {
    const nuevos = colas[apikey].splice(0);
    lote.cmds = [...lote.cmds, ...nuevos];
    console.log(`[COLA] ${String(apikey).substring(0, 12)} +${nuevos.length} comando(s) al lote en vuelo`);
  }

  let cuerpo = lote ? construirComandos(lote.cmds) : '';

  // Confirmación SIEMPRE al final del .rsc: si el MikroTik falla antes,
  // esta línea no se ejecuta, el lote sigue en vuelo y se reintenta.
  if (cuerpo.length > 0) {
    const host = String(req.headers.host || '5.161.88.42:3000').replace(/[^A-Za-z0-9.:\-]/g, '');
    cuerpo +=
      '\r\n' +
      `/tool fetch url="http://${host}/cola/ack?apikey=${encodeURIComponent(apikey)}&token=${lote.token}" mode=http dst-path=starkgo-ack.tmp\r\n` +
      '/file remove starkgo-ack.tmp';
  }

  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.send(cuerpo.length > 0 ? cuerpo + '\r\n' : '');
});

// GET /cola/ack → el MikroTik confirma que importó TODO el lote.
// Recién acá se borra: si nunca llega, se reenvía (comandos idempotentes).
app.get('/cola/ack', async (req, res) => {
  const { apikey, token } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  const lote = enVuelo[apikey];
  if (!lote) return res.json({ ok: true, comandos: 0, detalle: 'sin lote en vuelo' });
  if (!token || String(token) !== lote.token) {
    // Ack viejo (de un lote anterior): NO borramos el lote actual.
    return res.json({ ok: false, detalle: 'token no coincide' });
  }
  const cuantos = lote.cmds.length;
  delete enVuelo[apikey];
  ultimaConfirmacion[apikey] = Date.now();
  console.log(`[COLA] ${String(apikey).substring(0, 12)} confirmada (${cuantos} comandos)`);
  res.json({ ok: true, comandos: cuantos });
});

// GET /cola/estado → diagnóstico para la app (¿se aplicó en el router?).
app.get('/cola/estado', async (req, res) => {
  const { apikey } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  const lote = enVuelo[apikey] || null;
  res.json({
    ok: true,
    pendientes: (colas[apikey] || []).length,
    enVuelo: lote
      ? {
          comandos: lote.cmds.length,
          enviadoEn: new Date(lote.enviadoEn).toISOString(),
          edadSegundos: Math.round((Date.now() - lote.enviadoEn) / 1000),
        }
      : null,
    ultimaConfirmacion: ultimaConfirmacion[apikey]
      ? new Date(ultimaConfirmacion[apikey]).toISOString()
      : null,
    ttlSegundos: Math.round(COLA_TTL_MS / 1000),
  });
});

app.post('/bloquear', async (req, res) => {
  const { apikey, ip, nombre, portal } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  if (!ip || !nombre) return res.status(400).json({ error: 'Faltan datos' });
  encolar(apikey, { accion: 'bloquear', ip, nombre });
  // Portal de pago opcional (portalMorosos=true): deja la IP cautiva en el hotspot.
  if (portal === true || portal === 'true')
    encolar(apikey, { accion: 'hotspot-bloquear', ip, nombre });
  console.log(`[${apikey.substring(0,12)}] BLOQUEAR: ${nombre}`);
  res.json({ ok: true });
});

app.post('/desbloquear', async (req, res) => {
  const { apikey, ip, nombre, portal } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  if (!nombre) return res.status(400).json({ error: 'Faltan datos' });
  encolar(apikey, { accion: 'desbloquear', ip, nombre });
  // Portal de pago opcional: restaura el bypass del hotspot para ese IP.
  if (portal === true || portal === 'true')
    encolar(apikey, { accion: 'hotspot-desbloquear', ip, nombre });
  console.log(`[${apikey.substring(0,12)}] DESBLOQUEAR: ${nombre}`);
  res.json({ ok: true });
});

app.post('/limitar', async (req, res) => {
  const { apikey, ip, nombre, subida, bajada, burstBajada, burstSubida, umbralBajada, umbralSubida, tiempo, ordenVelocidad } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  if (!ip || !nombre || !subida || !bajada) return res.status(400).json({ error: 'Faltan datos' });
  if (colas[apikey]) colas[apikey] = colas[apikey].filter(c => !(c.accion === 'limitarMegas' && c.nombre === nombre));
  encolar(apikey, { accion: 'limitarMegas', ip, nombre, subida, bajada, burstBajada, burstSubida, umbralBajada, umbralSubida, tiempo, ordenVelocidad });
  console.log(`[${String(apikey).substring(0,12)}] LIMITAR: ${nombre}`);
  res.json({ ok: true });
});

// POST /encolar — encolado genérico (lo usa VpsService.encolar de la app).
// Sólo se aceptan las acciones conocidas y se copian únicamente los campos
// permitidos: nada de comandos RouterOS arbitrarios.
const ACCIONES_ENCOLABLES = new Set([
  'bloquear',
  'desbloquear',
  'hotspot-bloquear',
  'hotspot-desbloquear',
  'hotspot-blindar-admin',
  'marcarLease',
  'limitarMegas',
  'pppoeCrear',
  'pppoeEliminar',
]);
const CAMPOS_ENCOLABLES = [
  'ip',
  'mac',
  'nombre',
  'subida',
  'bajada',
  'burstBajada',
  'burstSubida',
  'umbralBajada',
  'umbralSubida',
  'tiempo',
  'usuario',
  'clave',
  'perfil',
  // 'subida-bajada' = la app nueva manda los valores con el orden real.
  // Sin este campo se asume el orden de la app vieja (invertido).
  'ordenVelocidad',
];

app.post('/encolar', async (req, res) => {
  const body = req.body || {};
  const { apikey } = body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  const accion = String(body.accion || '').trim();
  if (!ACCIONES_ENCOLABLES.has(accion))
    return res.status(400).json({ error: `Acción no permitida: "${accion}"` });

  const cmd = { accion };
  for (const k of CAMPOS_ENCOLABLES) {
    if (body[k] !== undefined && body[k] !== null) cmd[k] = body[k];
  }
  if (accion === 'limitarMegas') {
    if (!cmd.ip || !cmd.nombre || !cmd.subida || !cmd.bajada)
      return res.status(400).json({ error: 'Faltan datos' });
    // El mismo cliente sólo tiene UNA cola: reemplazamos la pendiente.
    if (colas[apikey])
      colas[apikey] = colas[apikey].filter(
        (c) => !(c.accion === 'limitarMegas' && c.nombre === cmd.nombre)
      );
  }
  if (accion === 'pppoeCrear' && (!cmd.usuario || !cmd.clave || !cmd.subida || !cmd.bajada))
    return res.status(400).json({ error: 'Faltan datos' });
  if (accion === 'pppoeEliminar' && !cmd.usuario)
    return res.status(400).json({ error: 'Falta: usuario' });

  encolar(apikey, cmd);
  console.log(`[${String(apikey).substring(0,12)}] ENCOLAR: ${accion} ${cmd.nombre || cmd.usuario || cmd.ip || ''}`);
  res.json({ ok: true });
});

app.post('/pppoe-crear', async (req, res) => {
  const { apikey, usuario, clave, nombre, subida, bajada, perfil } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  if (!usuario || !clave || !nombre || !subida || !bajada)
    return res.status(400).json({ error: 'Faltan datos' });
  const perfilNombre = (perfil && perfil.trim()) ? perfil.trim() : `starkgo_${usuario}`;
  if (colas[apikey])
    colas[apikey] = colas[apikey].filter(c => !(c.accion === 'pppoeCrear' && c.usuario === usuario));
  encolar(apikey, { accion: 'pppoeCrear', usuario, clave, nombre, subida, bajada, perfil: perfilNombre });
  console.log(`[${apikey.substring(0,12)}] PPPOE-CREAR: ${usuario}`);
  res.json({ ok: true, perfil: perfilNombre });
});

app.post('/pppoe-eliminar', async (req, res) => {
  const { apikey, usuario } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  if (!usuario) return res.status(400).json({ error: 'Falta: usuario' });
  encolar(apikey, { accion: 'pppoeEliminar', usuario });
  console.log(`[${apikey.substring(0,12)}] PPPOE-ELIMINAR: ${usuario}`);
  res.json({ ok: true });
});

app.get('/', (req, res) => {
  const resumen = {};
  for (const k of Object.keys(colas)) resumen[k.substring(0,12)] = colas[k].length;
  const vuelo = {};
  for (const k of Object.keys(enVuelo)) vuelo[k.substring(0,12)] = enVuelo[k].cmds.length;
  res.json({
    status: 'StarkGo API v2.7',
    // Marcador de despliegue: si acá NO aparecen los endpoints de WireGuard,
    // el VPS sigue con la versión vieja de index.js (falta subirla/reiniciar).
    endpoints_wireguard: [
      '/wg/info',
      '/wg/register',
      '/wg/register-mikrotik',
      '/wg/peers/:publicKey',
      '/wg/init',
    ],
    // Cola con entrega confirmada (Simple Queues / bindings / PPPoE).
    endpoints_cola: ['/cola', '/cola/ack', '/cola/estado', '/encolar'],
    colas_activas: resumen,
    colas_en_vuelo: vuelo,
    cola_ttl_segundos: Math.round(COLA_TTL_MS / 1000),
  });
});

// ═══════════════════════════════════════════════════════════
//  PORTAL VPS — página de pago remota para morosos
//  Guarda/sirve el HTML del portal (login.html) desde Firestore
//  para que se pueda editar desde cualquier lado (sin FTP local).
//  Colección: portal_vps/<apikey> → { paginas: { login.html: "<html>" } }
// ═══════════════════════════════════════════════════════════
function sanitizarArchivo(nombre) {
  return String(nombre || '').replace(/[^a-zA-Z0-9._-]/g, '');
}

// Lee una página tolerando las formas en que pudo quedar guardada:
//  - paginas.login.html  (mapa anidado, lo normal)
//  - "paginas.login.html" (campo plano con punto literal)
//  - html                (compatibilidad antigua, solo login)
function leerPaginaDelPortal(snap, nombre) {
  if (!snap.exists) return null;
  const data = snap.data() || {};
  if (data.paginas && typeof data.paginas === 'object') {
    const v = data.paginas[nombre];
    if (v) return v;
  }
  const plano = data[`paginas.${nombre}`];
  if (plano) return plano;
  if (nombre === 'login.html' && data.html) return data.html;
  return null;
}

function listarPaginasDelPortal(snap) {
  if (!snap.exists) return [];
  const data = snap.data() || {};
  const nombres = new Set();
  if (data.paginas && typeof data.paginas === 'object') {
    for (const k of Object.keys(data.paginas)) nombres.add(k);
  }
  for (const k of Object.keys(data)) {
    const m = /^paginas\.(.+)$/.exec(k);
    if (m) nombres.add(m[1]);
  }
  return Array.from(nombres);
}

// POST /hotspot/pagina  → guarda el HTML de una página del portal.
//   body: { apikey, archivo: "login.html", html: "<!DOCTYPE html>..." }
app.post('/hotspot/pagina', async (req, res) => {
  const { apikey, archivo, html } = req.body || {};
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  const nombre = sanitizarArchivo(archivo);
  if (!nombre || !html) return res.status(400).json({ error: 'Faltan archivo/html' });
  try {
    await db
      .collection('portal_vps')
      .doc(apikey)
      .set({ [`paginas.${nombre}`]: String(html), actualizado: new Date() }, { merge: true });
    console.log(`[PORTAL] ${String(apikey).substring(0, 12)} guardo ${nombre}`);
    res.json({ ok: true });
  } catch (e) {
    console.error('[PORTAL] Error guardando:', e.message);
    res.status(500).json({ error: 'Error guardando la pagina' });
  }
});

// ── Datos dinámicos del portal (nombre / saldo por cliente) ──────────
const formatearNumero = new Intl.NumberFormat('es-CO');

// Busca el cliente por su IP (la misma que está en la lista "morosos").
async function buscarClientePorIp(apikey, ip) {
  if (!ip) return null;
  try {
    const cfg = await db
      .collection('config_mikrotik')
      .where('vpsApiKey', '==', apikey)
      .limit(1)
      .get();
    if (cfg.empty) return null;
    const uid = cfg.docs[0].id;
    const clientes = await db
      .collection('clientes')
      .where('propietarioUid', '==', uid)
      .where('ipatn', '==', ip)
      .limit(1)
      .get();
    if (clientes.empty) return null;
    return clientes.docs[0].data() || null;
  } catch (e) {
    console.error('[PORTAL] Error buscando cliente por IP:', e.message);
    return null;
  }
}

// Rellena los marcadores del HTML con los datos reales del cliente.
// Marcadores: {{nombre}}, {{saldo}}, {{plan}}, {{ip}}, {{fecha}}
function rellenarDatosPortal(html, cliente, ip) {
  const nombre = cliente
    ? `${cliente.nombre || ''} ${cliente.apellido || ''}`.trim()
    : '';
  const plan = cliente ? String(cliente.planCliente || '') : '';
  let saldo = '';
  if (cliente) {
    const valor = Number(cliente.planValor || 0);
    const simbolo = String(cliente.planSimbolo || '$').trim();
    saldo = valor > 0
      ? `${simbolo} ${formatearNumero.format(valor)}`.trim()
      : '';
  }
  const reemplazos = {
    '{{nombre}}': nombre || 'Cliente',
    '{{saldo}}': saldo || '(consulta tu valor a pagar)',
    '{{plan}}': plan || 'plan de internet',
    '{{ip}}': ip || '',
    '{{fecha}}': new Date().toLocaleDateString('es-CO'),
  };
  let out = String(html);
  for (const k of Object.keys(reemplazos)) {
    out = out.split(k).join(reemplazos[k]);
  }
  return out;
}

// GET /portal/:apikey/:archivo → página pública (la carga el navegador del
// moroso / la vista previa de la app). Sin autenticacion a proposito.
// Si llega ?ip=... se rellenan los datos dinámicos del cliente.
// Si llega ?raw=1 se devuelve el HTML guardado tal cual (sin reemplazar los
// marcadores), para poder ver/copiar el código fuente desde la app.
app.get('/portal/:apikey/:archivo', async (req, res) => {
  const { apikey, archivo } = req.params;
  const nombre = sanitizarArchivo(archivo);
  try {
    const snap = await db.collection('portal_vps').doc(apikey).get();
    const html = leerPaginaDelPortal(snap, nombre);
    if (!html) return res.status(404).type('text/plain').send('Pagina no encontrada');

    res.setHeader('Content-Type', 'text/html; charset=utf-8');

    // ?raw=1 → devuelve el código guardado sin reemplazar marcadores.
    const raw = (req.query.raw || '').toString().toLowerCase();
    if (raw === '1' || raw === 'true') {
      return res.send(html);
    }

    const ip = (req.query.ip || '').toString().trim();
    const cliente = await buscarClientePorIp(apikey, ip);
    const finalHtml = rellenarDatosPortal(html, cliente, ip);

    res.send(finalHtml);
  } catch (e) {
    console.error('[PORTAL] Error leyendo:', e.message);
    res.status(500).type('text/plain').send('Error leyendo el portal');
  }
});

// GET /portal/:apikey → lista de paginas publicadas (para depuracion).
app.get('/portal/:apikey', async (req, res) => {
  const { apikey } = req.params;
  try {
    const snap = await db.collection('portal_vps').doc(apikey).get();
    res.json({ archivos: listarPaginasDelPortal(snap) });
  } catch (e) {
    res.status(500).json({ error: 'Error leyendo el portal' });
  }
});

// ═══════════════════════════════════════
//  MERCADOPAGO - Renovar Membresía
// ═══════════════════════════════════════
const { MercadoPagoConfig, Preference, Payment } = require('mercadopago');

// Token de Mercado Pago: variable de entorno → `functions/credenciales.local.json`
// → valor histórico de respaldo. (Antes estaba fijo acá: así se puede rotar sin
// tocar el código.)
const MP_ACCESS_TOKEN =
  credencial('MP_ACCESS_TOKEN') ||
  'APP_USR-2192060784339362-042316-e4103c6eba088eef4bf579cc39cff8cb-166839613';

const mpClient = new MercadoPagoConfig({ accessToken: MP_ACCESS_TOKEN });

// Caché corto en memoria para las consultas a las pasarelas durante el
// "auto-chequeo": la app pregunta cada pocos segundos mientras el pago está
// pendiente y no queremos golpear la API de ePayco/Mercado Pago en cada intento.
const cacheConsultas = new Map();
function conCache(clave, ttlMs, fn) {
  const hit = cacheConsultas.get(clave);
  if (hit && Date.now() - hit.t < ttlMs) return Promise.resolve(hit.v);
  return Promise.resolve()
    .then(fn)
    .then((v) => {
      if (cacheConsultas.size > 500) cacheConsultas.clear();
      cacheConsultas.set(clave, { t: Date.now(), v });
      return v;
    });
}

// ════════════════════════════════════════════════════════════════
//  PLANES MERCADOPAGO — Incluye planes de acceso completo Y vouchers
// ════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════
//  MONEDA DE LAS PASARELAS
//  Las cuentas de Colombia (Mercado Pago y Rapid) SOLO admiten COP.
//  `precio` = valor en USD, que es lo que muestra la app al cliente.
//  El COP se CALCULA con la tasa USD_A_COP (más abajo) → el precio que
//  se cobra siempre coincide con el equivalente que el cliente ve.
// ════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════
//  MONEDA / TASA DE CAMBIO  (USD → COP)  —  AUTOMÁTICA
//
//  Los planes están en USD (lo que ve el cliente) y las pasarelas
//  colombianas (Mercado Pago y Rapid) cobran en COP. La tasa se consulta
//  SOLA y se cachea; el COP de cada plan se calcula con ella, así el precio
//  que el cliente ve y el que se le cobra siempre son equivalentes.
//
//  Orden de fuentes (la primera que responda y sea razonable gana):
//    1. TRM oficial de Colombia (Superfinanciera · datos.gov.co)
//    2. currency-api (jsDelivr, sin key, con fecha)
//    3. open.er-api.com
//    4. exchangerate-api.com
//    5. Última tasa guardada en Firestore (sobrevive reinicios)
//
//  Variables opcionales:
//    USD_A_COP=3200          → fuerza una tasa FIJA (desactiva lo automático)
//    USD_A_COP_MARGEN=0      → % extra sobre la tasa (ej: 2 = +2%)
//    USD_A_COP_TTL_MIN=360   → cada cuántos minutos se re-consulta (6 h)
// ════════════════════════════════════════════════════════════════
const MP_CURRENCY = process.env.MP_CURRENCY || 'COP';
// Países donde Mercado Pago está disponible. La cuenta es de Colombia y solo
// cobra ahí, así que por defecto es "CO". La app pide el país del teléfono y
// solo muestra el botón si está en esta lista (`pasarelas.mercadoPago.paises`).
//   MP_PAISES=CO         → solo Colombia (por defecto)
//   MP_PAISES=CO,AR,BR   → varios países
//   MP_FORZAR=true       → mostrar el botón en TODO el mundo (solo pruebas)
const MP_PAISES = String(process.env.MP_PAISES || 'CO')
  .split(',')
  .map((p) => p.trim().toUpperCase())
  .filter((p) => p.length === 2);
const USD_A_COP_FIJA = process.env.USD_A_COP ? Number(process.env.USD_A_COP) : 0;
const USD_A_COP_MARGEN = Number(process.env.USD_A_COP_MARGEN || 0);
const TASA_TTL_MS = Number(process.env.USD_A_COP_TTL_MIN || 360) * 60 * 1000;
const TASA_MIN = 1000; // sanidad: fuera de este rango no se acepta
const TASA_MAX = 20000;

let tasaCache = { valor: 0, fuente: '', fecha: 0, actualizado: null };
let tasaEnCurso = null;

const tasaValida = (n) => Number.isFinite(n) && n >= TASA_MIN && n <= TASA_MAX;

// Tasa efectiva = tasa del día (+ margen configurado, si lo hay).
function tasaConMargen(valor) {
  return valor * (1 + USD_A_COP_MARGEN / 100);
}

// Consulta las fuentes públicas en orden. Devuelve { valor, fuente } o null.
async function consultarTasaFuentes() {
  const fuentes = [
    {
      nombre: 'TRM oficial (Superfinanciera)',
      url: 'https://www.datos.gov.co/resource/32sa-8pi3.json?$limit=1&$order=vigenciadesde%20DESC',
      leer: (j) => (Array.isArray(j) && j[0] ? Number(j[0].valor) : NaN),
    },
    {
      nombre: 'currency-api',
      url: 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
      leer: (j) => Number(j && j.usd && j.usd.cop),
    },
    {
      nombre: 'open.er-api.com',
      url: 'https://open.er-api.com/v6/latest/USD',
      leer: (j) => Number(j && j.rates && j.rates.COP),
    },
    {
      nombre: 'exchangerate-api.com',
      url: 'https://api.exchangerate-api.com/v4/latest/USD',
      leer: (j) => Number(j && j.rates && j.rates.COP),
    },
  ];

  for (const f of fuentes) {
    try {
      const resp = await fetch(f.url, {
        headers: { 'User-Agent': 'starkgo/1.0' },
        signal: AbortSignal.timeout(8000),
      });
      if (!resp.ok) continue;
      const valor = f.leer(await resp.json());
      if (tasaValida(valor)) {
        console.log(`[TASA] USD→COP = ${valor} (${f.nombre})`);
        return { valor, fuente: f.nombre };
      }
      console.warn(`[TASA] ${f.nombre} devolvió un valor inválido: ${valor}`);
    } catch (e) {
      console.warn(`[TASA] ${f.nombre} falló: ${e.message}`);
    }
  }
  return null;
}

// Tasa USD→COP del día (caché de 6 h + persistencia en Firestore).
async function obtenerTasaUsdCop({ forzar = false } = {}) {
  // 0) Tasa fija por variable de entorno (override manual).
  if (USD_A_COP_FIJA > 0) {
    return {
      valor: tasaConMargen(USD_A_COP_FIJA),
      fuente: 'USD_A_COP (fija por entorno)',
      fecha: Date.now(),
      actualizado: null,
    };
  }

  // 1) Caché en memoria.
  if (!forzar && tasaCache.valor > 0 && Date.now() - tasaCache.fecha < TASA_TTL_MS) {
    return tasaCache;
  }

  // 2) Evita consultas simultáneas (varias ventas a la vez).
  if (tasaEnCurso) return tasaEnCurso;

  tasaEnCurso = (async () => {
    // 2a) Última tasa guardada (sobrevive reinicios del VPS).
    let respaldo = null;
    try {
      const doc = await db.collection('config_precios').doc('tasa').get();
      if (doc.exists) respaldo = doc.data() || null;
    } catch (e) {
      console.warn('[TASA] No pude leer la tasa guardada:', e.message);
    }

    // 2b) Fuentes online.
    const nueva = await consultarTasaFuentes();
    if (nueva) {
      const item = {
        valor: tasaConMargen(nueva.valor),
        fuente: nueva.fuente,
        fecha: Date.now(),
        actualizado: new Date().toISOString(),
      };
      tasaCache = item;
      try {
        await db.collection('config_precios').doc('tasa').set(
          {
            valor: nueva.valor,
            valorConMargen: item.valor,
            margen: USD_A_COP_MARGEN,
            fuente: nueva.fuente,
            actualizado: admin.firestore.Timestamp.now(),
          },
          { merge: true }
        );
      } catch (e) {
        console.warn('[TASA] No pude guardar la tasa:', e.message);
      }
      return item;
    }

    // 2c) Último recurso: la última tasa guardada.
    if (respaldo && tasaValida(Number(respaldo.valorConMargen || respaldo.valor))) {
      console.warn('[TASA] Sin internet: uso la última tasa guardada');
      tasaCache = {
        valor: Number(respaldo.valorConMargen || respaldo.valor),
        fuente: (respaldo.fuente || 'guardada') + ' (última conocida)',
        fecha: Date.now(),
        actualizado: respaldo.actualizado ? String(respaldo.actualizado) : null,
      };
      return tasaCache;
    }

    throw new Error('No se pudo obtener la tasa USD→COP');
  })();

  try {
    return await tasaEnCurso;
  } finally {
    tasaEnCurso = null;
  }
}

// Monto en COP de un plan (redondeado a la centena).
function montoCop(plan, tasa) {
  if (!plan) return 0;
  if (plan.precioCop) return plan.precioCop; // override manual del plan
  const t = Number(tasa || 0);
  const cop = Math.round((Number(plan.precio) * t) / 100) * 100;
  return cop > 0 ? cop : 0;
}

// ── GET /precios — público: la app lo usa para mostrar el precio en COP ──
// ?refrescar=1 fuerza una consulta nueva de la tasa del dólar.
app.get('/precios', async (req, res) => {
  try {
    const tasa = await obtenerTasaUsdCop({ forzar: req.query.refrescar === '1' });
    await refrescarConfigRapid(); // para informar si Rapid está en producción
    const planes = {};
    for (const [id, p] of Object.entries(PLANES_MP)) {
      planes[id] = {
        usd: p.precio,
        cop: montoCop(p, tasa.valor),
        meses: p.meses,
        titulo: p.titulo,
        tipo: p.tipo,
      };
    }
    res.json({
      ok: true,
      usdACop: Math.round(tasa.valor * 100) / 100,
      fuente: tasa.fuente,
      actualizado: tasa.actualizado,
      margen: USD_A_COP_MARGEN,
      moneda: MP_CURRENCY,
      // La app usa esto para mostrar/ocultar los botones de pago:
      // produccion=false → botón OCULTO · true → botón VISIBLE.
      pasarelas: {
        // Rapid quedó reemplazada por ePayco: se muestra solo si
        // RAPID_ACTIVO=true en el VPS (así sigue oculta sin recompilar la app).
        rapid: {
          produccion: rapidProduccionPublicada(),
          modo: RAPID_CFG.modo,
          activo: RAPID_ACTIVO,
        },
        // ePayco: la pasarela del RESTO DEL MUNDO (en Colombia cobra MP).
        epayco: {
          produccion: EPAYCO_CFG.produccion,
          modo: EPAYCO_CFG.modo,
          paises: EPAYCO_CFG.paises,
          excluirPaises: EPAYCO_CFG.excluirPaises,
          forzar: EPAYCO_CFG.forzar,
          // En COP (la app lo compara contra el precio en COP): si el tope está
          // en USD, se convierte aquí con la tasa del día.
          montoMax: await epaycoMontoMaxCop(EPAYCO_CFG, tasa.valor),
        },
        // Mercado Pago solo opera en Colombia (la cuenta es CO): la app
        // muestra el botón únicamente si el teléfono está en uno de estos
        // países (variable MP_PAISES, ej: "CO" o "CO,AR").
        mercadoPago: {
          paises: MP_PAISES,
          forzar: aBool(process.env.MP_FORZAR),
        },
      },
      planes,
    });
  } catch (e) {
    console.error('[TASA] /precios:', e.message);
    res
      .status(503)
      .json({ ok: false, error: 'No se pudo obtener la tasa del dólar' });
  }
});

const PLANES_MP = {
  // ── Planes de acceso completo ──
  '1m': { precio: 15,  meses: 1,  titulo: '1 Mes StarkGo',   tipo: 'completo' },
  '3m': { precio: 39,  meses: 3,  titulo: '3 Meses StarkGo', tipo: 'completo' },
  '6m': { precio: 69,  meses: 6,  titulo: '6 Meses StarkGo', tipo: 'completo' },
  '1a': { precio: 120, meses: 12, titulo: '1 Año StarkGo',   tipo: 'completo' },
  // ── Planes Solo Vouchers ──
  'v1m': { precio: 3,  meses: 1,  titulo: 'Vouchers 1 Mes StarkGo',   tipo: 'vouchers' },
  'v3m': { precio: 8,  meses: 3,  titulo: 'Vouchers 3 Meses StarkGo', tipo: 'vouchers' },
  'v6m': { precio: 15, meses: 6,  titulo: 'Vouchers 6 Meses StarkGo', tipo: 'vouchers' },
  'v1a': { precio: 30, meses: 12, titulo: 'Vouchers 1 Año StarkGo',   tipo: 'vouchers' },
};

async function verificarTokenUsuario(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No autorizado' });
  }
  try {
    req.user = await admin.auth().verifyIdToken(auth.split('Bearer ')[1]);
    next();
  } catch (e) {
    console.error('[MP] Token inválido:', e.message);
    return res.status(401).json({ error: 'Token inválido' });
  }
}

app.post('/mp/crear-preferencia', verificarTokenUsuario, async (req, res) => {
  const { planId, nombre } = req.body;
  const { uid, email } = req.user;
  const plan = PLANES_MP[planId];
  if (!plan) return res.status(400).json({ error: 'Plan inválido' });
  try {
    // Precio en COP con la tasa del día (automática).
    const tasa = await obtenerTasaUsdCop();
    const preference = new Preference(mpClient);
    const result = await preference.create({
      body: {
        items: [{
          title: plan.titulo,
          quantity: 1,
          unit_price: montoCop(plan, tasa.valor),
          currency_id: MP_CURRENCY,
        }],
        payer: { email, name: nombre ?? '' },
        external_reference: `${uid}|${planId}`,
        back_urls: {
          success: 'starkgo://pago/exitoso',
          failure: 'starkgo://pago/fallido',
          pending: 'starkgo://pago/pendiente',
        },
        auto_return: 'approved',
        notification_url: 'http://5.161.88.42:3000/mp/webhook',
      },
    });
    console.log(`[MP] Preferencia creada uid=${uid} plan=${planId} valor=${montoCop(plan, tasa.valor)} ${MP_CURRENCY} (tasa ${tasa.valor.toFixed(2)})`);
    // Guardamos la orden: sirve para que "Verificar estado" (y el auto-chequeo
    // de la pantalla de pendiente) sepa qué compra está esperando este usuario.
    try {
      await db.collection('mp_ordenes').doc(String(result.id)).set(
        {
          uid,
          planId,
          plan: plan.titulo,
          monto: montoCop(plan, tasa.valor),
          moneda: MP_CURRENCY,
          preferenceId: String(result.id),
          estado: 'CREADA',
          creadoEn: admin.firestore.Timestamp.now(),
        },
        { merge: true }
      );
    } catch (e) {
      console.warn('[MP] No pude guardar la orden:', e.message);
    }
    res.json({
      initPoint: result.init_point,
      sandboxInitPoint: result.sandbox_init_point,
      ordenId: String(result.id),
    });
  } catch (e) {
    console.error('[MP] Error crear preferencia:', e.message);
    res.status(500).json({ error: 'Error al crear preferencia' });
  }
});

app.post('/mp/webhook', async (req, res) => {
  const { type, data } = req.body;
  if (type !== 'payment') return res.sendStatus(200);
  try {
    const paymentClient = new Payment(mpClient);
    const pago = await paymentClient.get({ id: data.id });
    console.log(
      `[MP] Webhook pago=${data.id} status=${pago.status} motivo=${pago.status_detail} ` +
      `tipo=${pago.payment_type_id} tarjeta=${pago.payment_method?.id} ` +
      `monto=${pago.transaction_amount} ${pago.currency_id}`
    );
    if (pago.status !== 'approved') {
      // Motivos típicos de rechazo:
      //  cc_rejected_high_risk          -> antifraude de Mercado Pago
      //  cc_rejected_call_for_authorize -> el banco pide autorizar (compra internacional)
      //  cc_rejected_insufficient_amount-> sin fondos
      //  cc_rejected_bad_filled_card_number / _date / _security_code -> datos mal
      console.warn(`[MP] ⚠️ Pago NO aprobado (${pago.status_detail}) — no se activa membresía`);
    }
    if (pago.status === 'approved') {
      const ref = String(pago.external_reference || '');
      if (!ref.includes('|')) {
        console.warn(`[MP] Pago ${pago.id} aprobado pero sin external_reference usable`);
        return res.sendStatus(200);
      }
      const [uid, planId] = ref.split('|');
      if (!uid || !PLANES_MP[planId]) return res.sendStatus(200);
      // ⚠️ Activación IDEMPOTENTE: antes esto extendía la membresía en cada
      //    notificación (si Mercado Pago repetía el webhook, se sumaban meses
      //    de más). Ahora usa la misma puerta que las demás pasarelas.
      const fecha = await activarMembresia(uid, planId, 'MP', `pago_${pago.id}`, 'mp_ordenes');
      await db.collection('mp_ordenes').doc(`pago_${pago.id}`).set(
        {
          uid,
          planId,
          pagoId: String(pago.id),
          estado: 'PAGADO',
          activado: true,
          monto: pago.transaction_amount,
          moneda: pago.currency_id,
          pagadoEn: admin.firestore.Timestamp.now(),
        },
        { merge: true }
      );
      if (!fecha) console.log(`[MP] Pago ${pago.id} ya estaba activado (se omite)`);
    }
    res.sendStatus(200);
  } catch (e) {
    console.error('[MP] Error webhook:', e.message);
    res.sendStatus(500);
  }
});

// ── Verificación de pagos de Mercado Pago ("Verificar estado") ──
// La app (y el auto-chequeo de la pantalla de pendiente) preguntan acá si el
// pago ya se acreditó. Antes esa pantalla consultaba sólo a Rapid, así que un
// pago con Mercado Pago quedaba "pendiente" para siempre.
async function mpBuscarPagosAprobados(uid, planId) {
  const ref = `${uid}|${planId}`;
  // Caché de 20 s: el auto-chequeo pregunta cada pocos segundos.
  return conCache(`mp:${ref}`, 20000, async () => {
    const url =
      'https://api.mercadopago.com/v1/payments/search' +
      `?sort=date_created&criteria=desc&limit=20&external_reference=${encodeURIComponent(ref)}`;
    const r = await fetch(url, { headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` } });
    const j = await r.json().catch(() => null);
    if (!r.ok) {
      console.warn(`[MP] Búsqueda de pagos HTTP ${r.status}: ${j ? JSON.stringify(j).slice(0, 200) : ''}`);
      return [];
    }
    const res = j && Array.isArray(j.results) ? j.results : [];
    return res.filter((p) => p && p.status === 'approved');
  });
}

// Activa lo que falte de los pagos APROBADOS de Mercado Pago (idempotente).
// Devuelve { activados, yaActivos } igual que `epaycoVerificarPagos()`.
async function mpVerificarPagos(uidFiltro, planFiltro) {
  const activados = [];
  const yaActivos = [];
  if (!uidFiltro) return { activados, yaActivos };

  // Qué planes buscar: el que pidió la app o, si no vino ninguno, los de las
  // compras registradas de ese usuario (una sola consulta a Firestore, así no
  // disparamos 8 búsquedas en la API de Mercado Pago en cada intento).
  let planes = planFiltro && PLANES_MP[planFiltro] ? [planFiltro] : [];
  if (!planes.length) {
    try {
      const snap = await db
        .collection('mp_ordenes')
        .where('uid', '==', String(uidFiltro))
        .limit(10)
        .get();
      planes = [
        ...new Set(
          snap.docs
            .map((d) => String((d.data() || {}).planId || ''))
            .filter((p) => PLANES_MP[p])
        ),
      ];
    } catch (e) {
      console.warn('[MP] No pude leer mp_ordenes:', e.message);
    }
    if (!planes.length) planes = Object.keys(PLANES_MP);
  }

  for (const planId of planes) {
    let pagos = [];
    try {
      pagos = await mpBuscarPagosAprobados(uidFiltro, planId);
    } catch (e) {
      console.warn(`[MP] No pude consultar los pagos (${planId}):`, e.message);
      continue;
    }
    for (const p of pagos) {
      const fecha = await activarMembresia(uidFiltro, planId, 'MP', `pago_${p.id}`, 'mp_ordenes');
      await db.collection('mp_ordenes').doc(`pago_${p.id}`).set(
        {
          uid: uidFiltro,
          planId,
          pagoId: String(p.id),
          estado: 'PAGADO',
          activado: true,
          monto: p.transaction_amount,
          moneda: p.currency_id,
          pagadoEn: admin.firestore.Timestamp.now(),
        },
        { merge: true }
      );
      const item = {
        pagoId: String(p.id),
        planId,
        monto: p.transaction_amount,
        moneda: p.currency_id,
      };
      if (fecha) activados.push(item);
      else yaActivos.push(item);
    }
  }
  return { activados, yaActivos };
}

// ── POST /mp/verificar — el botón "Verificar estado" (Mercado Pago) ──
app.post('/mp/verificar', verificarTokenUsuario, async (req, res) => {
  const { uid } = req.user;
  const planId = (req.body && req.body.planId) || '';
  try {
    let r = await mpVerificarPagos(uid, planId);
    if (!r.activados.length && !r.yaActivos.length && planId) {
      r = await mpVerificarPagos(uid, '');
    }
    const planes = [...r.activados, ...r.yaActivos].map((a) => a.planId);
    const pagado = planes.length > 0;
    console.log(
      `[MP] Verificar uid=${uid} plan=${planId || 'cualquiera'} → ` +
        `activados=${r.activados.length} yaActivos=${r.yaActivos.length} pagado=${pagado}`
    );
    res.json({
      ok: true,
      pagado,
      activados: r.activados.length,
      yaActivos: r.yaActivos.length,
      planes,
      pagos: [...r.activados, ...r.yaActivos],
    });
  } catch (e) {
    console.error('[MP] Error verificar:', e.message);
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ════════════════════════════════════════════════════════════════
//  EPAYCO — pasarela de pago (por defecto en TODOS los países,
//  incluida Colombia; en Colombia además está Mercado Pago)
//
//  Credenciales del panel de ePayco (Integraciones → Llaves de API):
//     EPAYCO_PUBLIC_KEY      = public_key   ← OBLIGATORIA (API + checkout)
//     EPAYCO_PRIVATE_KEY     = private_key  ← OBLIGATORIA (API)
//     EPAYCO_CUST_ID_CLIENTE = p_cust_id_cliente  (sólo para validar la
//     EPAYCO_P_KEY           = p_key              firma del webhook)
//     EPAYCO_MODE            = 'test' (pruebas) | 'live' (cobros reales)
//
//  🎛️  TODO SE MANEJA DESDE FIRESTORE → `config_pagos/epayco`
//       produccion     : false = botón OCULTO · true = VISIBLE en la app
//       modo           : 'test' cobra en pruebas · 'live' cobra de verdad
//       custIdCliente  : p_cust_id_cliente
//       pKey           : p_key
//       publicKey/privateKey : llaves del API (opcionales)
//       paises         : lista blanca (vacía = todos los países)
//       excluirPaises  : lista negra (vacía = ninguno excluido;
//                        poné ["CO"] si querés ocultarlo en Colombia)
//       forzar         : true = mostrar en TODO el mundo (pruebas)
//     Se relee cada PAGOS_TTL_MS y se publica el espejo público, así que
//     cambiás las llaves de producción y prendés el botón SIN tocar la app.
//
//  Flujo (idéntico al de Mercado Pago / Rapid para la app):
//     1. La app llama POST /epayco/crear-orden  → { initPoint }
//     2. El VPS crea la SESIÓN en la API de ePayco y devuelve
//        https://secure.epayco.co/checkout.php?sessionId=<id>
//     3. La app abre ese checkout en el WebView; el cliente paga
//     4. ePayco avisa por POST /epayco/confirmacion (activa la membresía)
//        y devuelve el navegador a GET /epayco/respuesta?ref_payco=<id>
//
//  ⚠️  El checkout CLÁSICO por URL (p_cust_id_cliente + p_key + x_signature)
//      YA NO EXISTE: la página del checkout es una SPA que sólo entiende
//      `sessionId`, así que con la URL clásica el cliente veía una **página
//      404**. Por eso ahora la orden se crea por API (ver abajo).
//
//  En el panel de ePayco, si hay que registrar URLs, usá:
//        URL de respuesta:     http://5.161.88.42:3000/epayco/respuesta
//        URL de confirmación:  http://5.161.88.42:3000/epayco/confirmacion
//
//  Firmas MD5 del checkout viejo (sólo se usan para *intentar* validar la
//  firma del webhook de confirmación; si no coincide se avisa en el log y,
//  por defecto, NO se bloquea el pago — ver `firmaObligatoria`):
//     x_signature (respuesta) = md5(p_cust_id_cliente ^ p_key ^ x_ref_payco
//                                   ^ x_transaction_id ^ x_amount ^ x_currency_code)
//     Si ePayco llegara a usar otra variante, revisá `epaycoFirmaRespuesta()`
//     y los logs: la firma recibida se compara y se avisa en el log.
//
//  Códigos de respuesta (x_cod_response):
//     1 = aceptada · 2 = rechazada · 3 = pendiente · 4 = fallida
// ════════════════════════════════════════════════════════════════
// Credenciales de RESPALDO: variables de entorno o `credenciales.local.json`.
// La fuente de verdad es `config_pagos/epayco` en Firestore (igual que
// Rapid): ahí podés cambiar llaves y pasar a producción sin tocar el VPS.
const EPAYCO_CUST_ID = credencial('EPAYCO_CUST_ID_CLIENTE');
const EPAYCO_P_KEY = credencial('EPAYCO_P_KEY');
// Llaves del API de ePayco (no las usa el checkout hospedado, pero quedan
// disponibles y se muestran enmascaradas en /epayco/diag).
const EPAYCO_PUBLIC_KEY = credencial('EPAYCO_PUBLIC_KEY');
const EPAYCO_PRIVATE_KEY = credencial('EPAYCO_PRIVATE_KEY');
const EPAYCO_MODE = (process.env.EPAYCO_MODE || 'test').toLowerCase(); // 'test' | 'live'
const EPAYCO_MONEDA = process.env.EPAYCO_CURRENCY || 'COP';
const EPAYCO_PAIS = process.env.EPAYCO_COUNTRY || 'CO';
const EPAYCO_VPS = process.env.EPAYCO_VPS_URL || 'http://5.161.88.42:3000';
const EPAYCO_CHECKOUT_URL =
  process.env.EPAYCO_CHECKOUT_URL || 'https://secure.epayco.co/checkout.php';

// 🚧 Tope de monto de ePayco (en COP). 0 = sin tope.
//   En modo PRUEBAS ePayco rechaza montos fuera de 5.000–200.000 COP.
//   Si lo cargás (Firestore `montoMax` o env EPAYCO_MONTO_MAX), la app
//   avisa con un mensaje claro "supera el monto máximo" en lugar del error
//   técnico de ePayco. En LIVE poné el tope real de tu cuenta (o 0).
const EPAYCO_MONTO_MAX = Number(process.env.EPAYCO_MONTO_MAX || 0);

// ¿En qué países se muestra el botón de ePayco?
//   EPAYCO_PAISES         → lista blanca (vacía = TODOS los países)
//   EPAYCO_EXCLUIR_PAISES → lista negra (VACÍA por defecto = TODOS los países,
//                           incluida Colombia). Si algún día querés que en
//                           Colombia solo cobre Mercado Pago, poné "CO".
//   EPAYCO_FORZAR=true    → mostrarlo en TODO el mundo (solo para pruebas)
const listaPaises = (valor) =>
  String(valor === undefined || valor === null ? '' : valor)
    .split(',')
    .map((p) => p.trim().toUpperCase())
    .filter((p) => p.length === 2);
const EPAYCO_PAISES = listaPaises(process.env.EPAYCO_PAISES);
const EPAYCO_EXCLUIR_PAISES = listaPaises(process.env.EPAYCO_EXCLUIR_PAISES);

// Config en uso (mutable: se refresca desde Firestore cada PAGOS_TTL_MS).
let EPAYCO_CFG = {
  // OJO: `produccion` sólo decide si el BOTÓN se muestra en la app
  // (el cobro real de pruebas/live lo decide `modo`).
  produccion: aBool(process.env.EPAYCO_PRODUCCION),
  modo: EPAYCO_MODE,
  custIdCliente: EPAYCO_CUST_ID,
  pKey: EPAYCO_P_KEY,
  publicKey: EPAYCO_PUBLIC_KEY,
  privateKey: EPAYCO_PRIVATE_KEY,
  moneda: EPAYCO_MONEDA,
  pais: EPAYCO_PAIS,
  paises: EPAYCO_PAISES,
  excluirPaises: EPAYCO_EXCLUIR_PAISES,
  forzar: aBool(process.env.EPAYCO_FORZAR),
  montoMax: EPAYCO_MONTO_MAX,
  checkoutUrl: EPAYCO_CHECKOUT_URL,
  firmaObligatoria: aBool(process.env.EPAYCO_FIRMA_OBLIGATORIA),
};
let epaycoCfgLeido = 0;

// MD5 en hexadecimal — es la firma que usa ePayco. Se hace el require acá
// adentro para que este módulo no dependa del `crypto` del bloque de PayPal.
function md5Hex(txt) {
  return require('crypto')
    .createHash('md5')
    .update(String(txt), 'utf8')
    .digest('hex');
}

// Firma de la ORDEN (la que viaja en la URL del checkout).
function epaycoFirmaOrden(cfg, idInvoice, monto, moneda) {
  return md5Hex(
    [cfg.custIdCliente, cfg.pKey, idInvoice, monto, moneda].join('^')
  );
}

// Firma que ePayco devuelve en la respuesta / confirmación.
function epaycoFirmaRespuesta(cfg, d) {
  return md5Hex(
    [
      cfg.custIdCliente,
      cfg.pKey,
      d.x_ref_payco,
      d.x_transaction_id,
      d.x_amount,
      d.x_currency_code,
    ].join('^')
  );
}

// ¿La firma que envió ePayco coincide con la esperada?
function epaycoFirmaOk(cfg, d) {
  const recibida = String(d.x_signature || '').trim().toLowerCase();
  if (!recibida) return false;
  return recibida === epaycoFirmaRespuesta(cfg, d).toLowerCase();
}

// ¿La transacción quedó APROBADA? (1 = aceptada · 3 = pendiente)
const epaycoAprobada = (codigo) => String(codigo || '').trim() === '1';
const epaycoPendiente = (codigo) => String(codigo || '').trim() === '3';

// Tope de ePayco EN COP **para la app**.
//
// ⚠️ El `montoMax` de Firebase está en la MISMA moneda que `moneda` (o sea, en
//    USD si cobrás en dólares), pero la app compara ese tope contra el precio
//    del plan en COP (`PreciosService.epaycoPermiteMonto(precioCop)`). Si le
//    mandábamos el número crudo (ej: 62), la app escondía el botón en TODOS los
//    planes. Por eso lo publicamos convertido con la tasa del día:
//      · moneda COP → se manda tal cual (no cambia nada).
//      · moneda USD → se convierte a COP con `montoCop` (mismo redondeo/margen
//        que usan los precios de `/precios`, así el tope y el precio son
//        directamente comparables).
//      · montoMax = 0 → 0 (sin tope).
//    El VPS sigue validando contra el valor crudo en `cfg.moneda`, así que el
//    tope real del cobro no cambia.
async function epaycoMontoMaxCop(cfg, tasa) {
  const max = Number((cfg && cfg.montoMax) || 0);
  if (!(max > 0)) return 0;
  if (String((cfg && cfg.moneda) || 'COP').toUpperCase() !== 'USD') return max;
  try {
    const t = Number(tasa) > 0 ? Number(tasa) : (await obtenerTasaUsdCop()).valor;
    return montoCop({ precio: max }, t);
  } catch (e) {
    // Sin tasa no inventamos un tope: 0 = sin tope (el botón se muestra y el
    // cobro real lo valida ePayco).
    console.warn('[EPAYCO] No pude convertir montoMax a COP:', e.message);
    return 0;
  }
}

// ════════════════════════════════════════════════════════════════
//  API DE ePayco — el checkout actual trabaja con SESIÓN, no con URL
//
//  ⚠️ IMPORTANTE (verificado contra ePayco el 2026-09-20):
//  el "checkout clásico" por URL (p_cust_id_cliente + p_key + x_signature)
//  YA NO EXISTE: la página del checkout es una SPA que sólo entiende
//  `sessionId` (por eso daba una página 404). El flujo correcto es:
//
//    1. POST {API}/login  (Basic base64(public_key:private_key)) → { token }
//    2. POST {API}/payment/session/create (Bearer token)         → { data.sessionId }
//    3. El cliente abre  https://secure.epayco.co/checkout.php?sessionId=<id>
//
//  Las llaves que valen son PUBLIC_KEY + PRIVATE_KEY (panel de ePayco).
//  custIdCliente/pKey quedan sólo para intentar validar la firma del
//  webhook de confirmación (si no coincide se avisa en el log; no bloquea).
// ════════════════════════════════════════════════════════════════
const EPAYCO_API_URL = process.env.EPAYCO_API_URL || 'https://apify.epayco.co';

// Token de la API (dura ~20 min: se renueva solo cuando está por vencer).
let epaycoToken = { valor: '', expira: 0 };

async function epaycoLogin({ forzar = false } = {}) {
  const cfg = await refrescarConfigEpayco();
  if (!cfg.publicKey || !cfg.privateKey) {
    throw new Error('faltan publicKey/privateKey de ePayco');
  }
  if (!forzar && epaycoToken.valor && Date.now() < epaycoToken.expira) {
    return epaycoToken.valor;
  }
  const basic = Buffer.from(`${cfg.publicKey}:${cfg.privateKey}`).toString('base64');
  const resp = await fetch(`${EPAYCO_API_URL}/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${basic}`,
    },
    body: '{}',
  });
  const txt = await resp.text();
  let json = null;
  try {
    json = JSON.parse(txt);
  } catch (_) {
    json = null;
  }
  if (!json || !json.token) {
    throw new Error(`ePayco login ${resp.status}: ${txt.slice(0, 200)}`);
  }
  epaycoToken = { valor: json.token, expira: Date.now() + 15 * 60 * 1000 };
  console.log('[EPAYCO] Token de API obtenido (válido 15 min)');
  return json.token;
}

// Crea la sesión de pago y devuelve el sessionId.
// ¿ePayco espera el checkout V2 para nuestra cuenta? (sólo informativo)
//   GET …/commerce/v2/check?publicKey=<PUB>  → { isV2: true|false }
// Con `false` (nuestro caso) el checkout válido es el CLÁSICO (V1) por JS:
//   ePayco.checkout.configure({ key, test }).open(datos)
async function epaycoEsV2(cfg) {
  try {
    const r = await fetch(
      'https://ms-checkout-create-transaction.epayco.co/commerce/v2/check?publicKey=' +
        encodeURIComponent(cfg.publicKey || ''),
      { headers: { Accept: 'application/json' } }
    );
    const j = await r.json();
    return j && (j.isV2 === true || j.isv2 === true);
  } catch (e) {
    console.warn('[EPAYCO] No pude consultar si la cuenta es V2:', e.message);
    return null;
  }
}

// Crea la sesión de pago (API V2 de ePayco) — sólo se usa en /epayco/diag.
// ⚠️ Límites de ePayco: en modo PRUEBAS el monto debe estar entre 5.000 y
// 200.000 COP (los planes de 6 meses y 1 año superan ese tope → hay que
// probarlos en LIVE o consultar con ePayco el tope de la cuenta).
async function epaycoCrearSesion(datos) {
  const token = await epaycoLogin();
  const resp = await fetch(`${EPAYCO_API_URL}/payment/session/create`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(datos),
  });
  const txt = await resp.text();
  let json = null;
  try {
    json = JSON.parse(txt);
  } catch (_) {
    json = null;
  }
  const sessionId = json && json.data && json.data.sessionId;
  if (!sessionId) {
    // ePayco responde 200 con success:false y una lista de errores muy
    // explicativa (ej: "property Amount must be between 5000 and 200000"):
    // la mostramos tal cual para no perder tiempo adivinando.
    const errores = json && json.data && Array.isArray(json.data.errors)
      ? json.data.errors.map((e) => e.errorMessage || e.codError).join(' | ')
      : '';
    const detalle = errores || (json && json.textResponse) || txt.slice(0, 400);
    throw new Error(`ePayco sesión ${resp.status}: ${detalle}`);
  }
  return sessionId;
}

// Busca una orden por su `ref_payco` (la vuelta del checkout trae ese id).
async function epaycoBuscarOrdenPorRef(ref) {
  if (!ref) return null;
  try {
    const snap = await db
      .collection('epayco_ordenes')
      .where('refPayco', '==', String(ref))
      .limit(1)
      .get();
    if (snap.docs && snap.docs.length) return snap.docs[0].data();
  } catch (e) {
    console.warn('[EPAYCO] No pude buscar la orden por ref:', e.message);
  }
  return null;
}

// Lee (o crea) `config_pagos/epayco` y deja EPAYCO_CFG actualizado.
// Mismo comportamiento que Rapid: si el documento no existe se crea en
// PRUEBAS (`produccion=false`) → el botón queda OCULTO en la app hasta que
// lo pongas en `true` desde la consola de Firebase.
async function refrescarConfigEpayco({ forzar = false } = {}) {
  if (!forzar && Date.now() - epaycoCfgLeido < PAGOS_TTL_MS) return EPAYCO_CFG;
  try {
    const ref = db.collection('config_pagos').doc('epayco');
    const doc = await ref.get();
    if (!doc.exists) {
      const base = {
        produccion: aBool(process.env.EPAYCO_PRODUCCION),
        modo: EPAYCO_MODE,
        custIdCliente: EPAYCO_CUST_ID,
        pKey: EPAYCO_P_KEY,
        publicKey: EPAYCO_PUBLIC_KEY,
        privateKey: EPAYCO_PRIVATE_KEY,
        pais: EPAYCO_PAIS,
        moneda: EPAYCO_MONEDA,
        paises: EPAYCO_PAISES,
        excluirPaises: EPAYCO_EXCLUIR_PAISES,
        forzar: aBool(process.env.EPAYCO_FORZAR),
        montoMax: EPAYCO_MONTO_MAX,
        firmaObligatoria: aBool(process.env.EPAYCO_FIRMA_OBLIGATORIA),
        nota:
          'produccion=false → botón OCULTO en la app · true → VISIBLE. modo: test|live (decide si se cobra de verdad). ' +
          'paises=lista blanca (vacía = todos) · excluirPaises=lista negra (vacía = TODOS, incluida Colombia; poné CO para ocultarlo en Colombia).',
        actualizado: admin.firestore.Timestamp.now(),
      };
      await ref.set(base, { merge: true });
      EPAYCO_CFG = { ...base, checkoutUrl: EPAYCO_CHECKOUT_URL };
      epaycoCfgLeido = Date.now();
      console.log('[PAGOS] config_pagos/epayco CREADA (botón oculto)');
      await publicarEspejoPasarelas();
      return EPAYCO_CFG;
    }
    const d = doc.data() || {};
    const produccion = aBool(d.produccion);
    // OJO: si falta `modo` se usa el del VPS / archivo local (test|live).
    // NO se deduce de `produccion`, para que prender el botón nunca active
    // cobros reales por accidente.
    const modo = String(d.modo || EPAYCO_MODE).toLowerCase();
    EPAYCO_CFG = {
      produccion,
      produccionCrudo: d.produccion === undefined ? '(falta el campo)' : String(d.produccion),
      modo,
      custIdCliente: String(d.custIdCliente || EPAYCO_CUST_ID).trim(),
      pKey: String(d.pKey || EPAYCO_P_KEY).trim(),
      publicKey: String(d.publicKey || EPAYCO_PUBLIC_KEY).trim(),
      privateKey: String(d.privateKey || EPAYCO_PRIVATE_KEY).trim(),
      moneda: String(d.moneda || EPAYCO_MONEDA).trim(),
      pais: String(d.pais || EPAYCO_PAIS).trim(),
      paises: listaPaises(d.paises === undefined ? EPAYCO_PAISES : d.paises),
      excluirPaises: listaPaises(
        d.excluirPaises === undefined ? EPAYCO_EXCLUIR_PAISES : d.excluirPaises
      ),
      forzar: d.forzar === undefined ? aBool(process.env.EPAYCO_FORZAR) : aBool(d.forzar),
      montoMax: Number(d.montoMax === undefined ? EPAYCO_MONTO_MAX : d.montoMax) || 0,
      checkoutUrl: String(d.checkoutUrl || EPAYCO_CHECKOUT_URL).trim(),
      firmaObligatoria:
        d.firmaObligatoria === undefined
          ? aBool(process.env.EPAYCO_FIRMA_OBLIGATORIA)
          : aBool(d.firmaObligatoria),
    };
    epaycoCfgLeido = Date.now();
    await publicarEspejoPasarelas();
  } catch (e) {
    console.error('[EPAYCO] No pude leer config_pagos/epayco (uso respaldo):', e.message);
    epaycoCfgLeido = Date.now() - PAGOS_TTL_MS + 10000; // reintenta en 10 s
  }
  return EPAYCO_CFG;
}

// Número de factura único que le mandamos a ePayco (x_id_invoice).
// Formato: SG-<6 del uid>-<tiempo en base 36>.
function epaycoIdInvoice(uid) {
  return `SG-${String(uid || '').slice(0, 6)}-${Date.now().toString(36).toUpperCase()}`;
}

// Activa la membresía de una transacción de ePayco (IDEMPOTENTE).
// `datos` = lo que manda ePayco (respuesta del navegador o confirmación).
// Devuelve true si quedó activa (o ya lo estaba) y false si no aplica.
async function epaycoActivarTransaccion(datos, cfg, origen) {
  const idInvoice = String(datos.x_id_invoice || '').trim();
  const refPayco = String(datos.x_ref_payco || '').trim();
  const codigo = String(datos.x_cod_response || '').trim();

  // uid / planId: primero en la orden guardada; si no, en x_extra1/x_extra2.
  let uid = String(datos.x_extra1 || '').trim();
  let planId = String(datos.x_extra2 || '').trim();
  let monto = Number(datos.x_amount || 0);
  if (idInvoice) {
    const snap = await db.collection('epayco_ordenes').doc(idInvoice).get();
    if (snap.exists) {
      const o = snap.data() || {};
      uid = uid || o.uid || '';
      planId = planId || o.planId || '';
      monto = monto || Number(o.monto || 0);
    }
  }

  // Guardamos SIEMPRE lo que respondió ePayco (sirve de auditoría).
  const datosOrden = {
    idInvoice: idInvoice || null,
    refPayco: refPayco || null,
    transaccionId: String(datos.x_transaction_id || '') || null,
    // Estado legible para soporte (en `epayco_ordenes/<factura>`):
    // PAGADO · PENDIENTE · RECHAZADO
    estado: epaycoAprobada(codigo)
      ? 'PAGADO'
      : epaycoPendiente(codigo)
        ? 'PENDIENTE'
        : 'RECHAZADO',
    codResponse: codigo || null,
    respuesta: String(datos.x_response || '') || null,
    motivo: String(datos.x_response_reason_text || '') || null,
    franquicia: String(datos.x_franchise || '') || null,
    emailCliente: String(datos.x_customer_email || '') || null,
    monto,
    moneda: String(datos.x_currency_code || '').trim() || null,
    origen,
    actualizadoEn: admin.firestore.Timestamp.now(),
  };
  await db
    .collection('epayco_ordenes')
    .doc(idInvoice || refPayco || `sin-factura-${Date.now()}`)
    .set(datosOrden, { merge: true });

  if (!uid || !planId) {
    // Respaldo: buscar la orden por `ref_payco` (por si el webhook no trae
    // x_extra1/x_extra2 ni la factura nuestra).
    const otra = await epaycoBuscarOrdenPorRef(refPayco);
    if (otra) {
      uid = uid || otra.uid || '';
      planId = planId || otra.planId || '';
      monto = monto || Number(otra.monto || 0);
    }
  }
  if (!uid || !planId) {
    console.warn(`[EPAYCO] (${origen}) No pude identificar uid/plan: factura=${idInvoice} ref=${refPayco}`);
    return false;
  }
  if (!epaycoAprobada(codigo)) {
    console.log(`[EPAYCO] (${origen}) Transacción NO aprobada: cod=${codigo} factura=${idInvoice}`);
    return false;
  }
  const fecha = await activarMembresia(
    uid,
    planId,
    'ePayco',
    refPayco ? `pago_${refPayco}` : null,
    'epayco_ordenes'
  );
  if (fecha) {
    // Deja la factura marcada como activada (para soporte).
    await db
      .collection('epayco_ordenes')
      .doc(idInvoice || `pago_${refPayco}`)
      .set({ activado: true, activadoEn: admin.firestore.Timestamp.now() }, { merge: true });
  }
  return !!fecha;
}

// Busca una clave en un JSON de ePayco sin depender del nivel ni de las
// mayúsculas (la API usa nombres distintos según el endpoint).
function buscarClaveEnJson(obj, nombres, profundidad = 3) {
  if (!obj || typeof obj !== 'object' || profundidad < 0) return undefined;
  const buscados = nombres.map((n) => String(n).toLowerCase());
  for (const [k, v] of Object.entries(obj)) {
    if (buscados.includes(String(k).toLowerCase())) return v;
  }
  for (const v of Object.values(obj)) {
    const r = buscarClaveEnJson(v, nombres, profundidad - 1);
    if (r !== undefined) return r;
  }
  return undefined;
}

// Estado REAL de una transacción en ePayco.
//   GET {API}/transaction/detail?refPayco=<ref>
// Verificado contra la API (21/09/2026): existe y responde 200.
// Sirve para no depender del webhook de confirmación: si el cliente pagó y la
// notificación no llegó, igual sabemos que está aprobada.
async function epaycoConsultarEstado(refPayco) {
  if (!refPayco) return null;
  const token = await epaycoLogin();
  const resp = await fetch(
    `${EPAYCO_API_URL}/transaction/detail?refPayco=${encodeURIComponent(refPayco)}`,
    { headers: { Accept: 'application/json', Authorization: `Bearer ${token}` } }
  );
  const txt = await resp.text();
  let json = null;
  try {
    json = JSON.parse(txt);
  } catch (_) {
    json = null;
  }
  if (!json) return null;
  const j = json.data && typeof json.data === 'object' ? json.data : json;
  const codigo = String(
    buscarClaveEnJson(j, ['x_cod_response', 'codresponse', 'cod_response', 'x_cod_respuesta']) ?? ''
  ).trim();
  const estado = String(
    buscarClaveEnJson(j, ['x_transaction_state', 'transaction_state', 'estado', 'status']) ?? ''
  ).trim();
  const ok =
    codigo === '1' || /aceptad|aprobad|exitos|paid|complet/i.test(estado);
  return {
    ok,
    codigo: codigo || (ok ? '1' : ''),
    estado,
    idInvoice: String(buscarClaveEnJson(j, ['x_id_invoice', 'id_invoice', 'invoice']) ?? ''),
    refPayco: String(buscarClaveEnJson(j, ['x_ref_payco', 'ref_payco', 'referencepayco']) ?? refPayco),
    transaccionId: String(buscarClaveEnJson(j, ['x_transaction_id', 'transaction_id']) ?? ''),
    monto: Number(buscarClaveEnJson(j, ['x_amount', 'amount']) ?? 0) || null,
    moneda: String(buscarClaveEnJson(j, ['x_currency_code', 'currency_code', 'currency']) ?? ''),
    franquicia: String(buscarClaveEnJson(j, ['x_franchise', 'franchise']) ?? ''),
    email: String(buscarClaveEnJson(j, ['x_customer_email', 'customer_email', 'email']) ?? ''),
    crudo: json,
  };
}

// ── Pagos de ePayco ya ACREDITADOS de un usuario (activa lo que falte) ──
// Lo usa el botón "Verificar estado" de la app y `/epayco/reparar` (soporte).
//
// Se apoya en `epayco_ordenes/<factura>`, que el VPS escribe tanto cuando vuelve
// el navegador (`/epayco/respuesta`) como cuando llega el webhook
// (`/epayco/confirmacion`): si ahí quedó `estado: PAGADO`, el cobro existe.
//
// · `activado` lo pone `epaycoActivarTransaccion` cuando ya extendió la
//   membresía → en ese caso lo contamos como pagado pero NO se extiende de nuevo.
// · Sin `orderBy` a propósito: así no hace falta crear un índice compuesto
//   (uid + fecha) en Firestore para que esto funcione.
async function epaycoVerificarPagos(uidFiltro, planFiltro) {
  const activados = [];
  const yaActivos = [];
  if (!uidFiltro) return { activados, yaActivos };
  const snap = await db
    .collection('epayco_ordenes')
    .where('uid', '==', String(uidFiltro))
    .limit(25)
    .get();
  const cfg = await refrescarConfigEpayco();
  let consultas = 0; // para no golpear la API de ePayco si hay muchas órdenes
  for (const d of snap.docs) {
    const o = d.data() || {};
    const factura = d.id;
    // El espejo de idempotencia (`pago_<ref>`) no es una orden de compra.
    if (factura.startsWith('pago_')) continue;
    if (String(o.uid || '') !== String(uidFiltro)) continue;
    const planId = String(o.planId || '');
    if (!PLANES_MP[planId]) continue;
    if (planFiltro && planId !== planFiltro) continue;
    const refPayco = String(o.refPayco || '');
    let estado = String(o.estado || '').toUpperCase();

    // Si la orden NO figura pagada pero tenemos la referencia, le preguntamos a
    // ePayco el estado REAL de la transacción: cubre el caso "el cliente pagó
    // pero el webhook de confirmación nunca llegó".
    if (estado !== 'PAGADO' && refPayco && consultas < 5) {
      consultas++;
      try {
        // Caché de 20 s: el auto-chequeo de la app pregunta cada pocos segundos.
        const det = await conCache(`epayco:${refPayco}`, 20000, () =>
          epaycoConsultarEstado(refPayco)
        );
        if (det && det.ok) {
          console.log(
            `[EPAYCO] Consulta ${refPayco} → ${det.estado || det.codigo} (APROBADA) factura=${factura}`
          );
          await epaycoActivarTransaccion(
            {
              x_id_invoice: det.idInvoice || factura,
              x_ref_payco: det.refPayco || refPayco,
              x_cod_response: det.codigo || '1',
              x_transaction_id: det.transaccionId || '',
              x_amount: det.monto || '',
              x_currency_code: det.moneda || '',
              x_franchise: det.franquicia || '',
              x_customer_email: det.email || '',
              // uid/planId explícitos (los saca de la orden guardada).
              x_extra1: String(o.uid || uidFiltro),
              x_extra2: planId,
            },
            cfg,
            'consulta'
          );
          estado = 'PAGADO';
        } else if (det && det.estado) {
          console.log(`[EPAYCO] Consulta ${refPayco} → ${det.estado} (no aprobada)`);
        }
      } catch (e) {
        console.warn(`[EPAYCO] No pude consultar ${refPayco}:`, e.message);
      }
    }
    if (estado !== 'PAGADO') continue;

    if (o.activado === true) {
      yaActivos.push({ factura, planId, refPayco: refPayco || null });
      continue;
    }
    const fecha = await activarMembresia(
      uidFiltro,
      planId,
      'ePayco',
      refPayco ? `pago_${refPayco}` : `epayco_${factura}`,
      'epayco_ordenes'
    );
    await db
      .collection('epayco_ordenes')
      .doc(factura)
      .set(
        {
          activado: true,
          activadoEn: admin.firestore.Timestamp.now(),
          activadoPor: 'verificar',
        },
        { merge: true }
      );
    if (fecha) {
      activados.push({ factura, planId, refPayco: refPayco || null });
    } else {
      // Ya estaba activada (la misma compra): no se extendió otra vez.
      yaActivos.push({ factura, planId, refPayco: refPayco || null });
    }
  }
  return { activados, yaActivos };
}

// ── POST /epayco/crear-orden — devuelve la URL del checkout hospedado ──
// Mismo contrato que /mp/crear-preferencia y /rapid/crear-orden:
// responde { initPoint } con la URL a la que el WebView debe navegar.
app.post('/epayco/crear-orden', verificarTokenUsuario, async (req, res) => {
  const { planId } = req.body || {};
  const { uid } = req.user;
  const plan = PLANES_MP[planId];
  if (!plan) return res.status(400).json({ error: 'Plan inválido' });
  try {
    const cfg = await refrescarConfigEpayco();
    if (!cfg.publicKey || !cfg.privateKey) {
      // Mensaje corto (se muestra en la app) + detalle en el log del VPS.
      console.warn(
        '[EPAYCO] Faltan llaves: cargá publicKey y privateKey en config_pagos/epayco ' +
          '(o en las variables de entorno / functions/credenciales.local.json).'
      );
      return res.status(503).json({
        error: 'ePayco todavía no está configurado (faltan las llaves public_key y private_key).',
      });
    }
    // Precio: en USD (lo que paga el cliente de otros países) o en COP.
    // ePayco acepta USD y lo convierte a COP internamente (y aplica su tope).
    const esUsd = String(cfg.moneda || 'COP').toUpperCase() === 'USD';
    const tasa = await obtenerTasaUsdCop();
    const monto = esUsd ? Number(plan.precio) : montoCop(plan, tasa.valor);
    // Tope de ePayco (en pruebas ≈ 200.000 COP ≈ USD 62). Si está configurado
    // `montoMax` (en la MISMA moneda), avisamos claro en vez del error técnico.
    if (cfg.montoMax > 0 && monto > cfg.montoMax) {
      console.warn(`[EPAYCO] Monto ${monto} ${cfg.moneda} supera el tope configurado (${cfg.montoMax})`);
      return res.status(400).json({
        error:
          `ePayco no acepta ${monto} ${cfg.moneda} en este plan (su máximo es ${cfg.montoMax} ${cfg.moneda}). ` +
          'Elegí otro plan o pagá con Mercado Pago.',
      });
    }
    const idInvoice = epaycoIdInvoice(uid);

    // Validamos las llaves contra la API (login). El checkout CLÁSICO (V1)
    // crea la transacción él mismo desde la página /epayco/checkout.
    await epaycoLogin();

    await db.collection('epayco_ordenes').doc(idInvoice).set(
      {
        uid,
        planId,
        plan: plan.titulo,
        monto,
        moneda: cfg.moneda,
        estado: 'CREADA',
        modo: cfg.modo,
        produccion: cfg.produccion,
        creadoEn: admin.firestore.Timestamp.now(),
      },
      { merge: true }
    );
    console.log(
      `[EPAYCO] Orden ${idInvoice} uid=${uid} plan=${planId} ` +
        `monto=${monto} ${cfg.moneda} (${cfg.modo}, tasa ${tasa.valor.toFixed(2)})`
    );
    res.json({
      // La app abre ESTA página nuestra: ella lanza el checkout de ePayco
      // con TODOS los datos del plan (monto incluido).
      initPoint: `${EPAYCO_VPS}/epayco/checkout?factura=${idInvoice}`,
      ordenId: idInvoice,
    });
  } catch (e) {
    console.error('[EPAYCO] Error crear orden:', e.message);
    // Se devuelve el motivo real: la app lo muestra en el aviso y así se
    // diagnostica en segundos (ej: "ePayco login 401", "ePayco sesión 400: …").
    res.status(500).json({ error: `No se pudo crear la orden de pago: ${e.message}` });
  }
});

// ── GET /epayco/checkout?factura=SG-…  (o ?sessionId=…) ──
// Página que abre el WebView (la URL que devuelve /epayco/crear-orden).
//
// ⚠️ CÓMO FUNCIONA EL CHECKOUT DE ePAYCO (verificado 20/09/2026):
//  · La página `secure.epayco.co/checkout.php?…` por URL ya NO sirve (da 404).
//  · Hay dos variantes y ePayco decide cuál con una API:
//        GET https://ms-checkout-create-transaction.epayco.co/commerce/v2/check?publicKey=<PUB>
//    → { "isV2": false }  ⇒ NUESTRA CUENTA ES **V1** (usa el checkout clásico por JS).
//  · Flujo correcto (V1):  ePayco.checkout.configure({ key, test }).open(datos)
//    donde `datos` lleva name, description, invoice, currency, amount, tax,
//    tax_base, country, lang, external, response, confirmation. El checkout
//    CREA la transacción y la muestra en un iframe de secure.epayco.co.
//    (Con el flujo V2 por `sessionId` el checkout quedaba en $0.00.)
//  · Los datos se leen de NUESTRA orden (`epayco_ordenes/<factura>`) y no del
//    query string, así nadie puede cambiar el monto desde la URL.
app.get('/epayco/checkout', async (req, res) => {
  try {
    const cfg = await refrescarConfigEpayco();
    const factura = String(req.query.factura || '').trim();
    let sessionId = String(req.query.sessionId || '').trim();
    let orden = null;
    if (factura) {
      const snap = await db.collection('epayco_ordenes').doc(factura).get();
      if (snap.exists) orden = snap.data() || null;
    }
    if (!sessionId && orden) sessionId = String(orden.sessionId || '');
    if (!factura && !sessionId) {
      return res.status(400).send('Falta la factura o el sessionId');
    }
    if (orden && String(orden.estado || '').toUpperCase() === 'PAGADO') {
      return res.redirect('starkgo://pago/exitoso');
    }

    const datos = {
      name: 'StarkGo',
      description: (orden && orden.plan) || 'Plan StarkGo',
      invoice: factura || sessionId,
      currency: (orden && orden.moneda) || cfg.moneda,
      amount: Number((orden && orden.monto) || 0),
      tax_base: 0,
      tax: 0,
      country: cfg.pais,
      lang: 'es',
      external: 'false',
      response: `${EPAYCO_VPS}/epayco/respuesta`,
      confirmation: `${EPAYCO_VPS}/epayco/confirmacion`,
      methodconfirmation: 'POST',
    };

    const pagina = `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>StarkGo · Pago seguro</title>
<style>
  body{margin:0;font-family:-apple-system,Roboto,Arial,sans-serif;background:#0F172A;color:#fff;
       display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center}
  .caja{padding:24px;max-width:520px}
  .chico{font-size:13px;opacity:.65;margin-top:6px}
  a{color:#00C6AE}
</style>
</head>
<body>
<div class="caja">
  <p id="msg">Abriendo el checkout de ePayco…</p>
  <p class="chico" id="detalle"></p>
</div>
<script src="https://checkout.epayco.co/checkout.js"></script>
<script>
(function () {
  var KEY = ${JSON.stringify(cfg.publicKey || '')};
  var TEST = ${cfg.modo === 'live' ? 'false' : 'true'};
  var DATOS = ${JSON.stringify(datos)};
  function aviso(html) { document.getElementById('msg').innerHTML = html; }
  function detalle(html) { document.getElementById('detalle').innerHTML = html; }
  var VOLVER = '<br><br><a href="starkgo://pago/pendiente">Volver a la app</a>';
  function error(d) {
    console.error('[StarkGo] checkout:', d);
    aviso('No se pudo abrir el checkout de ePayco. Intenta de nuevo.' + VOLVER);
  }
  detalle(DATOS.description + ' · ' + DATOS.amount + ' ' + DATOS.currency);
  if (!window.ePayco || !ePayco.checkout || typeof ePayco.checkout.configure !== 'function') {
    return error('checkout.js no cargó');
  }
  try {
    // Flujo CLÁSICO (V1): la clave va en configure() y los datos en open().
    var handler = ePayco.checkout.configure({ key: KEY, test: TEST });
    if (!handler || typeof handler.open !== 'function') return error('sin handler');
    var p = handler.open(DATOS);
    if (p && typeof p.catch === 'function') p.catch(function (e) { error(e && e.message); });
  } catch (e) {
    error(e && e.message);
  }
})();
</script>
</body>
</html>`;
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.send(pagina);
  } catch (e) {
    console.error('[EPAYCO] checkout:', e.message);
    res.status(500).send('Error abriendo el checkout');
  }
});

// ── GET /epayco/respuesta — el navegador del cliente volvió de ePayco ──
// ePayco manda TODO por la URL (GET): factura, referencia, estado y firma.
// Activamos la membresía si la transacción fue aceptada y volvemos a la app
// con el deep link que ya entiende el WebView.
app.get('/epayco/respuesta', async (req, res) => {
  try {
    const d = req.query || {};
    const cfg = await refrescarConfigEpayco();
    const codigo = String(d.x_cod_response || '').trim();
    const ref = String(d.ref_payco || d.x_ref_payco || '').trim();
    console.log(
      `[EPAYCO] Volvió el cliente: factura=${d.x_id_invoice || '-'} cod=${codigo || '(sin cod)'} ` +
        `ref=${ref || '-'} session=${d.sessionId || '-'}`
    );

    // (1) Postback completo (trae x_cod_response): se activa al instante.
    if (codigo) {
      if (!epaycoFirmaOk(cfg, d)) {
        console.warn(
          '[EPAYCO] ⚠️ La firma de la respuesta no coincide con la esperada. ' +
            'Revisá que las llaves del VPS sean las de la MISMA cuenta de ePayco.'
        );
        if (cfg.firmaObligatoria) return res.redirect('starkgo://pago/fallido');
      }
      // Se guarda siempre (auditoría); se activa sólo si fue aceptada.
      await epaycoActivarTransaccion(d, cfg, 'respuesta');
      if (epaycoAprobada(codigo)) return res.redirect('starkgo://pago/exitoso');
      if (epaycoPendiente(codigo)) return res.redirect('starkgo://pago/pendiente');
      return res.redirect('starkgo://pago/fallido');
    }

    // (2) Vuelta del checkout: sólo trae ?ref_payco=<id> (sin `x_cod_response`).
    //     Antes esto quedaba en "pendiente" hasta que llegara el webhook.
    //     Ahora, si tenemos la referencia, le preguntamos a ePayco el estado
    //     REAL de la transacción y activamos si ya está aprobada → la app ve el
    //     éxito al volver, sin depender de la confirmación.
    const orden = await epaycoBuscarOrdenPorRef(ref);
    let estado = String((orden && orden.estado) || '').toUpperCase();
    if (orden) {
      console.log(`[EPAYCO] ref=${ref} → orden en estado ${estado || '(sin estado)'}`);
    } else {
      console.log(`[EPAYCO] ref=${ref} todavía sin confirmación registrada`);
    }

    if (estado !== 'PAGADO' && ref) {
      try {
        const det = await epaycoConsultarEstado(ref);
        if (det && det.ok) {
          console.log(`[EPAYCO] ref=${ref} → consulta APROBADA (${det.estado || det.codigo})`);
          const idInv = det.idInvoice || String(d.x_id_invoice || '');
          const activo = await epaycoActivarTransaccion(
            {
              x_id_invoice: idInv,
              x_ref_payco: det.refPayco || ref,
              x_cod_response: det.codigo || '1',
              x_transaction_id: det.transaccionId || '',
              x_amount: det.monto || '',
              x_currency_code: det.moneda || '',
              x_franchise: det.franquicia || '',
              x_customer_email: det.email || '',
            },
            cfg,
            'consulta'
          );
          // ⚠️ No alcanza con que ePayco diga "aprobada": si no pudimos
          // identificar la orden (o ya estaba activada) confirmamos con la
          // orden guardada antes de decirle "exitoso" al cliente.
          let yaEstaba = false;
          if (!activo && idInv) {
            const od = await db.collection('epayco_ordenes').doc(idInv).get();
            yaEstaba = od.exists && od.data().activado === true;
          }
          if (activo || yaEstaba) {
            estado = 'PAGADO';
          } else {
            console.warn(
              `[EPAYCO] ref=${ref} está aprobada pero no pude activarla ` +
                `(factura=${idInv || 'sin factura'}). Revisá /epayco/reparar?factura=…`
            );
          }
        } else if (det && det.estado) {
          console.log(`[EPAYCO] ref=${ref} → consulta: ${det.estado} (no aprobada)`);
          estado = estado || det.estado.toUpperCase();
        }
      } catch (e) {
        console.warn(`[EPAYCO] No pude consultar ${ref}:`, e.message);
      }
    }

    const estadoNorm = /rechaz|fallid|declinad|cancel/i.test(estado) ? 'RECHAZADO' : estado;
    if (estadoNorm === 'PAGADO') return res.redirect('starkgo://pago/exitoso');
    if (estadoNorm === 'RECHAZADO') return res.redirect('starkgo://pago/fallido');
    return res.redirect('starkgo://pago/pendiente');
  } catch (e) {
    console.error('[EPAYCO] Error respuesta:', e.message);
    return res.redirect('starkgo://pago/fallido');
  }
});

// ── POST /epayco/confirmacion — notificación de ePayco (respaldo) ──
// Llega por `application/x-www-form-urlencoded` y SIN sesión del cliente.
// Es la vía que activa la membresía cuando el cliente cierra el WebView
// antes de volver a la app.
app.post('/epayco/confirmacion', async (req, res) => {
  try {
    const d = { ...(req.body || {}), ...(req.query || {}) };
    const cfg = await refrescarConfigEpayco();
    const codigo = String(d.x_cod_response || '').trim();
    const firmaOk = epaycoFirmaOk(cfg, d);
    console.log(
      `[EPAYCO] Confirmación factura=${d.x_id_invoice || ''} cod=${codigo || '(falta)'} ` +
        `firma=${firmaOk ? 'OK' : 'NO COINCIDE'} ref=${d.x_ref_payco || ''}`
    );
    if (!firmaOk && cfg.firmaObligatoria) {
      console.warn('[EPAYCO] Confirmación descartada: firma inválida (firmaObligatoria=true)');
      return res.status(401).send('firma inválida');
    }
    const activado = await epaycoActivarTransaccion(d, cfg, 'confirmacion');
    // ePayco sólo espera un 200 para dar por recibida la notificación.
    res.status(200).send(activado ? 'activado' : 'recibido');
  } catch (e) {
    console.error('[EPAYCO] Error confirmación:', e.message);
    res.status(500).send('error');
  }
});

// ── GET /epayco/diag — comprueba la configuración en 1 segundo ──
// Abrí esta URL en el navegador: muestra si están las llaves, si la API de
// ePayco acepta el login y devuelve un CHECKOUT REAL de prueba para pagar.
app.get('/epayco/diag', async (req, res) => {
  try {
    const cfg = await refrescarConfigEpayco({ forzar: req.query.refrescar === '1' });
    const tasa = await obtenerTasaUsdCop();
    // Monto a probar (por defecto, el plan de 1 Mes):
    //   · ?planId=1a     → monto de ESE plan en la moneda configurada
    //   · ?monto=383100  → monto exacto en la moneda configurada (cfg.moneda)
    // Sirve para saber si TU cuenta acepta ese monto: con las llaves de
    // PRODUCCIÓN y `?planId=1a` sabés en un segundo si podés vender el plan de
    // 1 Año con ePayco, sin que el cliente tenga que intentarlo.
    const planPedido = PLANES_MP[String(req.query.planId || '').trim()] || null;
    const planIdDiag = planPedido ? String(req.query.planId).trim() : '1m';
    const planTituloDiag = planPedido
      ? planPedido.titulo
      : 'PRUEBA StarkGo (no activa membresía)';
    const esUsdDiag = String(cfg.moneda || 'COP').toUpperCase() === 'USD';
    // Tope de cordura para ?monto= (endpoint público): no dejamos que se pidan
    // montos absurdos sólo para probar el límite de la cuenta.
    const montoCrudo = Number(req.query.monto || 0);
    const topeSano = esUsdDiag ? 500 : 5000000;
    const montoPedido = Number.isFinite(montoCrudo)
      ? Math.min(Math.max(montoCrudo, 0), topeSano)
      : 0;
    const monto =
      montoPedido > 0
        ? montoPedido
        : esUsdDiag
          ? Number((planPedido || PLANES_MP['1m']).precio)
          : montoCop(planPedido || PLANES_MP['1m'], tasa.valor);

    // (1) ¿La API de ePayco acepta las llaves? (login)
    let apiOk = false;
    let apiError = '';
    try {
      await epaycoLogin({ forzar: true });
      apiOk = true;
    } catch (e) {
      apiError = e.message;
    }

    // (2) Sesión de pago REAL de prueba (se puede pagar desde el navegador)
    let sessionId = '';
    let errorSesion = '';
    if (apiOk) {
      try {
        sessionId = await epaycoCrearSesion({
          checkout_version: '2',
          name: 'StarkGo',
          description: `PRUEBA ${planTituloDiag} (no activa membresía)`,
          invoice: epaycoIdInvoice('DIAG'),
          currency: cfg.moneda,
          amount: monto,
          tax: 0,
          tax_base: 0,
          country: cfg.pais,
          lang: 'es',
          external: 'false',
          confirmation: `${EPAYCO_VPS}/epayco/confirmacion`,
          response: `${EPAYCO_VPS}/epayco/respuesta`,
        });
      } catch (e) {
        errorSesion = e.message;
      }
    }

    // (2.b) Si ePayco rechazó el monto, el error trae el rango EXACTO que
    //       acepta la cuenta:
    //       "[VALIDATION_ERROR] - property Amount must be between 5000 and 5000000"
    //       Lo exponemos para no tener que adivinar el tope (verificado
    //       21/09/2026 con las llaves de sandbox: 5.000–5.000.000 COP).
    let limiteEpayco = null;
    const rango = /between\s+(\d+)\s+and\s+(\d+)/i.exec(String(errorSesion || ''));
    if (rango) {
      limiteEpayco = {
        min: Number(rango[1]),
        max: Number(rango[2]),
        moneda: 'COP',
        fuente: 'ePayco (respuesta de la API)',
      };
    }

    // (3) ¿Se puede guardar la orden en Firestore? (misma escritura que hace
    //     /epayco/crear-orden: si esto falla, el pago da error 500)
    let ordenTest = '';
    let errorOrdenTest = '';
    if (sessionId) {
      ordenTest = epaycoIdInvoice('DIAG');
      try {
        await db.collection('epayco_ordenes').doc(ordenTest).set(
          {
            uid: 'DIAG',
            planId: planIdDiag,
            plan: `${planTituloDiag} · prueba de monto`,
            monto,
            moneda: cfg.moneda,
            sessionId,
            estado: 'PRUEBA',
            modo: cfg.modo,
            produccion: cfg.produccion,
            creadoEn: admin.firestore.Timestamp.now(),
          },
          { merge: true }
        );
      } catch (e) {
        errorOrdenTest = e.message;
      }
    }

    // (4) ¿Qué flujo de checkout espera ePayco para nuestra cuenta?
    const esV2 = await epaycoEsV2(cfg);

    res.json({
      ok: apiOk && !!ordenTest,
      produccion: cfg.produccion,
      produccionCrudo: cfg.produccionCrudo,
      modo: cfg.modo,
      apiOk,
      apiError: apiError || null,
      esV2,
      flujoCheckout: esV2 === true ? 'V2 (sessionId)' : 'V1 (clásico por JS)',
      sessionId: sessionId || null,
      errorSesion: errorSesion || null,
      // Qué monto se probó y si la cuenta lo aceptó. Probar otro plan/monto:
      //   /epayco/diag?planId=1a&refrescar=1      (monto del plan 1 Año)
      //   /epayco/diag?monto=383100&refrescar=1   (monto exacto, en cfg.moneda)
      planProbado: planIdDiag,
      montoProbado: monto,
      monedaProbada: cfg.moneda,
      montoAceptado: !!sessionId,
      urlProbarPlan1a: `${EPAYCO_VPS}/epayco/diag?planId=1a&refrescar=1`,
      // Rango permitido que informa ePayco cuando el monto no entra (null si
      // el monto pasó: en ese caso tu cuenta acepta ese monto).
      limiteEpayco,
      ordenTest: ordenTest || null,
      errorOrdenTest: errorOrdenTest || null,
      custIdCliente: cfg.custIdCliente || '(falta)',
      pKey: cfg.pKey ? maskClave(cfg.pKey) : '(falta)',
      publicKey: cfg.publicKey || '(falta)',
      privateKey: cfg.privateKey ? maskClave(cfg.privateKey) : '(falta)',
      moneda: cfg.moneda,
      paises: cfg.paises,
      excluirPaises: cfg.excluirPaises,
      forzar: cfg.forzar,
      montoMax: cfg.montoMax,
      // Tope que ve la app: en COP (si `moneda` es USD, va convertido).
      montoMaxAppCop: await epaycoMontoMaxCop(cfg, tasa.valor),
      firmaObligatoria: cfg.firmaObligatoria,
      tasaUsdCop: tasa.valor,
      // Pegá esto en el navegador del celular para ver el checkout de ePayco:
      urlCheckoutPrueba: ordenTest ? `${EPAYCO_VPS}/epayco/checkout?factura=${ordenTest}` : null,
    });
  } catch (e) {
    console.error('[EPAYCO] diag:', e.message);
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ── GET /epayco/test-orden?planId=1m — prueba el PAGO completo ──
// Hace exactamente lo mismo que /epayco/crear-orden (sesión en ePayco +
// guardar la orden en Firestore) pero con un uid ficticio, así se puede
// diagnosticar sin usar el celular. Sólo funciona en modo `test`.
app.get('/epayco/test-orden', async (req, res) => {
  try {
    const cfg = await refrescarConfigEpayco({ forzar: req.query.refrescar === '1' });
    if (cfg.modo === 'live') {
      return res.status(403).json({
        ok: false,
        error: 'Este endpoint sólo funciona en modo test (modo=live).',
      });
    }
    const planId = String(req.query.planId || '1m');
    const plan = PLANES_MP[planId];
    if (!plan) {
      return res.status(400).json({
        ok: false,
        error: 'Plan inválido (usá 1m, 3m, 6m, 1a, v1m, v3m, v6m o v1a)',
      });
    }
    const uid = 'DIAGTEST';
    const tasa = await obtenerTasaUsdCop();
    const esUsd = String(cfg.moneda || 'COP').toUpperCase() === 'USD';
    const monto = esUsd ? Number(plan.precio) : montoCop(plan, tasa.valor);
    // Mismo control que /epayco/crear-orden (tope configurado, en cfg.moneda).
    if (cfg.montoMax > 0 && monto > cfg.montoMax) {
      return res.status(400).json({
        ok: false,
        paso: 'tope',
        planId,
        monto,
        montoMax: cfg.montoMax,
        moneda: cfg.moneda,
        error: `El plan supera el tope de ePayco (${cfg.montoMax} ${cfg.moneda}): ${monto} ${cfg.moneda}`,
      });
    }
    const idInvoice = epaycoIdInvoice(uid);

    try {
      // Sólo validamos las llaves (el checkout V1 crea la transacción él mismo).
      await epaycoLogin();
    } catch (e) {
      console.error('[EPAYCO] test-orden (login):', e.message);
      return res.status(500).json({ ok: false, paso: 'login', planId, monto, error: e.message });
    }

    try {
      await db.collection('epayco_ordenes').doc(idInvoice).set(
        {
          uid,
          planId,
          plan: plan.titulo,
          monto,
          moneda: cfg.moneda,
          estado: 'CREADA',
          modo: cfg.modo,
          produccion: cfg.produccion,
          creadoEn: admin.firestore.Timestamp.now(),
        },
        { merge: true }
      );
    } catch (e) {
      console.error('[EPAYCO] test-orden (firestore):', e.message);
      return res.status(500).json({ ok: false, paso: 'firestore', planId, monto, error: e.message });
    }

    res.json({
      ok: true,
      planId,
      monto,
      ordenId: idInvoice,
      urlCheckout: `${EPAYCO_VPS}/epayco/checkout?factura=${idInvoice}`,
    });
  } catch (e) {
    console.error('[EPAYCO] test-orden:', e.message);
    res.status(500).json({ ok: false, paso: 'general', error: e.message });
  }
});

// ── GET /epayco/estado?factura=SG-... — qué pasó con una orden ──
// Útil para soporte: devuelve lo que guardó el VPS de esa factura.
app.get('/epayco/estado', async (req, res) => {
  try {
    const factura = String(req.query.factura || '').trim();
    if (!factura) return res.status(400).json({ error: 'Falta ?factura=' });
    const doc = await db.collection('epayco_ordenes').doc(factura).get();
    if (!doc.exists) return res.status(404).json({ ok: false, error: 'No existe esa factura' });
    res.json({ ok: true, factura, orden: doc.data() });
  } catch (e) {
    console.error('[EPAYCO] estado:', e.message);
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ── POST /epayco/verificar — el botón "Verificar estado" (ePayco) ──
// La app lo llama con el token de Firebase. Busca las órdenes de ePayco del
// usuario que ya estén PAGADAS y activa lo que falte (idempotente).
// Devuelve el mismo contrato que `/rapid/verificar`: { pagado, activados, planes }.
app.post('/epayco/verificar', verificarTokenUsuario, async (req, res) => {
  const { uid } = req.user;
  const planId = (req.body && req.body.planId) || '';
  try {
    let r = await epaycoVerificarPagos(uid, planId);
    // Nada de ESE plan → buscamos cualquier pago acreditado del usuario.
    if (!r.activados.length && !r.yaActivos.length && planId) {
      r = await epaycoVerificarPagos(uid, '');
    }
    const planes = [...r.activados, ...r.yaActivos].map((a) => a.planId);
    const pagado = planes.length > 0;
    console.log(
      `[EPAYCO] Verificar uid=${uid} plan=${planId || 'cualquiera'} → ` +
        `activados=${r.activados.length} yaActivos=${r.yaActivos.length} pagado=${pagado}`
    );
    res.json({
      ok: true,
      pagado,
      activados: r.activados.length,
      yaActivos: r.yaActivos.length,
      planes,
      ordenes: [...r.activados, ...r.yaActivos],
    });
  } catch (e) {
    console.error('[EPAYCO] Error verificar:', e.message);
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ── GET /epayco/reparar — soporte: activar un pago que quedó pendiente ──
// (sólo con la apikey admin, igual que /consumo/manual)
//   /epayco/reparar?apikey=…&factura=SG-XXXXXX-YYYY   → activa ESA factura
//   /epayco/reparar?apikey=…&uid=UID_DEL_CLIENTE      → activa todas sus
//                                                        órdenes PAGADAS
app.get('/epayco/reparar', async (req, res) => {
  if (req.query.apikey !== 'starkgo_admin_2025') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  const factura = String(req.query.factura || '').trim();
  const uid = String(req.query.uid || '').trim();
  try {
    // (a) Una factura concreta.
    if (factura) {
      const doc = await db.collection('epayco_ordenes').doc(factura).get();
      if (!doc.exists) {
        return res.status(404).json({ ok: false, error: 'No existe esa factura' });
      }
      const o = doc.data() || {};
      const estado = String(o.estado || '').toUpperCase();
      if (estado !== 'PAGADO') {
        return res.json({
          ok: true,
          activado: false,
          factura,
          estado: estado || '(todavía sin estado)',
          pista:
            'ePayco no confirmó este cobro como PAGADO. Mirá el pago en el panel ' +
            'de ePayco y, si está aprobado, revisá que la URL de confirmación ' +
            'apunte a /epayco/confirmacion.',
        });
      }
      const planId = String(o.planId || '');
      const uidOrden = String(o.uid || '');
      const refPayco = String(o.refPayco || '');
      if (!PLANES_MP[planId] || !uidOrden) {
        return res.status(400).json({
          ok: false,
          error: `La orden no tiene datos usables (planId=${planId || '-'}, uid=${uidOrden || '-'})`,
        });
      }
      const fecha = await activarMembresia(
        uidOrden,
        planId,
        'ePayco',
        refPayco ? `pago_${refPayco}` : `epayco_${factura}`,
        'epayco_ordenes'
      );
      await db
        .collection('epayco_ordenes')
        .doc(factura)
        .set(
          {
            activado: true,
            activadoEn: admin.firestore.Timestamp.now(),
            activadoPor: 'reparar',
          },
          { merge: true }
        );
      console.log(`[EPAYCO] Reparar factura=${factura} uid=${uidOrden} plan=${planId} → ${fecha ? 'ACTIVADO' : 'ya estaba'}`);
      return res.json({
        ok: true,
        activado: !!fecha,
        yaEstaba: !fecha,
        factura,
        uid: uidOrden,
        planId,
        refPayco: refPayco || null,
        vence: fecha ? fecha.toISOString() : null,
      });
    }

    // (b) Todas las órdenes PAGADAS de un usuario.
    if (!uid) {
      return res.status(400).json({ ok: false, error: 'Falta ?factura= o ?uid=' });
    }
    const r = await epaycoVerificarPagos(uid, '');
    res.json({
      ok: true,
      uid,
      activados: r.activados.length,
      yaActivos: r.yaActivos.length,
      ordenes: [...r.activados, ...r.yaActivos],
    });
  } catch (e) {
    console.error('[EPAYCO] reparar:', e.message);
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ── GET /epayco/ordenes — soporte: últimas órdenes de ePayco ──
// (sólo con la apikey admin)
//   /epayco/ordenes?apikey=…&limite=20          → las 20 más recientes
//   /epayco/ordenes?apikey=…&uid=UID_DEL_CLIENTE
// Sirve para ver por qué un pago quedó en "pendiente" (estado, ref, activado).
app.get('/epayco/ordenes', async (req, res) => {
  if (req.query.apikey !== 'starkgo_admin_2025') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  const uid = String(req.query.uid || '').trim();
  const limite = Math.min(Math.max(Number(req.query.limite || 20) || 20, 1), 100);
  try {
    const base = db.collection('epayco_ordenes');
    // Con `uid` no hace falta índice compuesto; sin `uid` ordenamos por fecha
    // (índice automático de un solo campo).
    const q = uid ? base.where('uid', '==', uid) : base.orderBy('creadoEn', 'desc');
    const snap = await q.limit(limite).get();
    res.json({
      ok: true,
      total: snap.size,
      ordenes: snap.docs.map((d) => {
        const o = d.data() || {};
        let creado = null;
        try {
          creado = o.creadoEn && o.creadoEn.toDate ? o.creadoEn.toDate().toISOString() : null;
        } catch (_) {}
        return {
          factura: d.id,
          uid: o.uid || null,
          planId: o.planId || null,
          monto: o.monto === undefined ? null : o.monto,
          moneda: o.moneda || null,
          estado: o.estado || null,
          codResponse: o.codResponse || null,
          refPayco: o.refPayco || null,
          activado: o.activado === true,
          origen: o.origen || null,
          creadoEn: creado,
        };
      }),
    });
  } catch (e) {
    console.error('[EPAYCO] ordenes:', e.message);
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ════════════════════════════════════════════════════════════════
//  RAPID (antes Rapyd) - Renovar Membresía
//
//  Credenciales del panel de Rapid (Developers → API keys):
//     RAPID_ACCESS_KEY = rak_...      RAPID_SECRET_KEY = rsk_...
//     RAPID_MODE       = 'sandbox' (pruebas) | 'live' (cobros reales)
//
//  Flujo (idéntico al de Mercado Pago):
//     1. La app llama POST /rapid/crear-orden   → { initPoint }
//     2. La app abre el WebView con el checkout hospedado de Rapid
//     3. El cliente paga y Rapid redirige a GET /rapid/retorno
//     4. Rapid además notifica POST /rapid/webhook (respaldo)
//
//  ⚠️  En el panel de Rapid hay que dar de alta la URL del webhook:
//        http://5.161.88.42:3000/rapid/webhook      (Sandbox Y Live)
//      La firma del webhook se calcula sobre ESA URL exacta; si cambia,
//      definí RAPID_WEBHOOK_URL con el valor real.
//
//  Firma de cada request (según el SDK oficial de Rapid):
//     base64( HMAC_SHA256_HEX(secret,
//             method + path + salt + timestamp + access_key + secret + body) )
// ════════════════════════════════════════════════════════════════
// Credenciales de RESPALDO: variables de entorno o `credenciales.local.json`
// (archivo local, está en .gitignore y NO se sube a git).
// La fuente de verdad es `config_pagos/rapid` en Firestore (ver abajo): ahí
// podés cambiar accessKey/secretKey y pasar a producción sin tocar el VPS.
const RAPID_ACCESS_KEY = credencial('RAPID_ACCESS_KEY');
const RAPID_SECRET_KEY = credencial('RAPID_SECRET_KEY');
if (!RAPID_ACCESS_KEY || !RAPID_SECRET_KEY) {
  console.warn(
    '[RAPID] ⚠️ Faltan RAPID_ACCESS_KEY / RAPID_SECRET_KEY. ' +
      'Ponelas en variables de entorno del VPS o en functions/credenciales.local.json ' +
      '(o cargá config_pagos/rapid en Firestore).'
  );
}
const RAPID_MODE = (process.env.RAPID_MODE || 'sandbox').toLowerCase(); // 'sandbox' | 'live'
// 🔌 INTERRUPTOR DE RAPID (sin recompilar la app):
//   RAPID_ACTIVO=true  → Rapid vuelve a mostrarse en la app
//   (por defecto queda APAGADO: ahora el cobro es Mercado Pago en Colombia y
//    ePayco en el resto del mundo)
// Los endpoints /rapid/* siguen funcionando, sólo se oculta el botón.
const RAPID_ACTIVO = aBool(process.env.RAPID_ACTIVO);
const RAPID_PAIS = process.env.RAPID_COUNTRY || 'CO';
const RAPID_MONEDA = process.env.RAPID_CURRENCY || 'COP';
const RAPID_VPS = process.env.RAPID_VPS_URL || 'http://5.161.88.42:3000';
const RAPID_WEBHOOK_URL = process.env.RAPID_WEBHOOK_URL || `${RAPID_VPS}/rapid/webhook`;

// ════════════════════════════════════════════════════════════════
//  CONFIG DINÁMICA DE PAGOS  →  Firestore:  config_pagos/rapid
//
//    produccion : false = SANDBOX  → el botón NO se muestra en la app
//                 true  = PRODUCCIÓN → el botón SÍ se muestra
//    modo       : 'sandbox' | 'live'  (opcional; si falta se deduce de
//                 `produccion`). Para probar en sandbox CON el botón
//                 visible: produccion=true + modo='sandbox'.
//    accessKey  : rak_...   (panel de Rapid)
//    secretKey  : rsk_...   (panel de Rapid)
//    pais/moneda: CO / COP
//    webhookUrl : URL pública del webhook (la firma se calcula sobre ella)
//
//  Si el documento NO existe, el VPS lo CREA con los valores de sandbox
//  del código → después lo editás desde Firebase y listo. Se relee cada
//  PAGOS_TTL_MS (1 minuto), sin reiniciar el VPS.
//
//  🔒 ESTA COLECCIÓN GUARDA LLAVES SECRETAS: en las reglas de Firestore
//     tiene que quedar sin acceso de clientes:
//        match /config_pagos/{doc} { allow read, write: if false; }
// ════════════════════════════════════════════════════════════════
const PAGOS_TTL_MS = process.env.PAGOS_TTL_SEG
  ? Number(process.env.PAGOS_TTL_SEG) * 1000
  : Number(process.env.PAGOS_TTL_MIN || 0.25) * 60 * 1000; // 15 s por defecto
const RAPID_HOST_SANDBOX = 'sandboxapi.rapyd.net';
const RAPID_HOST_LIVE = 'api.rapyd.net';

// Config en uso (mutable: se refresca desde Firestore).
let RAPID_CFG = {
  produccion: RAPID_MODE === 'live',
  modo: RAPID_MODE,
  accessKey: RAPID_ACCESS_KEY,
  secretKey: RAPID_SECRET_KEY,
  pais: RAPID_PAIS,
  moneda: RAPID_MONEDA,
  webhookUrl: RAPID_WEBHOOK_URL,
  host: RAPID_MODE === 'live' ? RAPID_HOST_LIVE : RAPID_HOST_SANDBOX,
};
let rapidCfgLeido = 0; // marca de la última lectura de Firestore

// Enmascara una clave para logs/diagnóstico (nunca la muestra completa).
function maskClave(k) {
  const s = String(k || '');
  return s.length < 10 ? '***' : `${s.slice(0, 6)}…${s.slice(-4)}`;
}

// Convierte a booleano de forma TOLERANTE: en la consola de Firebase es muy
// fácil que un campo quede como texto ("true") o número (1) en vez de booleano.
function aBool(v) {
  if (v === true) return true;
  if (v === false || v === null || v === undefined) return false;
  if (typeof v === 'number') return v !== 0;
  if (typeof v === 'string') {
    return ['true', '1', 'si', 'sí', 'yes', 'on', 'activo'].includes(
      v.trim().toLowerCase()
    );
  }
  return false;
}

// ── Espejo PÚBLICO (sin secretos) para que la app lo lea EN TIEMPO REAL ──
// `config_publica/pasarelas` la escribe SOLO el VPS; la app la escucha con
// un listener de Firestore → el botón cambia al instante cuando editás
// `config_pagos/rapid`, sin recompilar ni reiniciar nada.
let espejoPublicado = null;

async function publicarEspejoPasarelas() {
  // Tope de ePayco en COP (la app lo compara contra el precio en COP): si en
  // Firebase está en USD, se convierte con la tasa del día.
  const montoMaxEpayco = await epaycoMontoMaxCop(EPAYCO_CFG);
  const actual = JSON.stringify({
    rapid: rapidProduccionPublicada(),
    epayco: EPAYCO_CFG.produccion,
    epaycoModo: EPAYCO_CFG.modo,
    epaycoPaises: EPAYCO_CFG.paises,
    epaycoExcluir: EPAYCO_CFG.excluirPaises,
    epaycoForzar: EPAYCO_CFG.forzar,
    epaycoMontoMax: montoMaxEpayco,
    mpPaises: MP_PAISES,
    mpForzar: aBool(process.env.MP_FORZAR),
  });
  if (actual === espejoPublicado) return;
  try {
    await db
      .collection('config_publica')
      .doc('pasarelas')
      .set(
        {
          rapid: {
            produccion: rapidProduccionPublicada(),
            modo: RAPID_CFG.modo,
            activo: RAPID_ACTIVO,
          },
          epayco: {
            produccion: EPAYCO_CFG.produccion,
            modo: EPAYCO_CFG.modo,
            moneda: EPAYCO_CFG.moneda,
            paises: EPAYCO_CFG.paises,
            excluirPaises: EPAYCO_CFG.excluirPaises,
            forzar: EPAYCO_CFG.forzar,
            montoMax: montoMaxEpayco,
          },
          // Mercado Pago solo opera en Colombia: la app muestra el botón
          // únicamente si el teléfono está en uno de estos países.
          mercadoPago: {
            paises: MP_PAISES,
            forzar: aBool(process.env.MP_FORZAR),
          },
          actualizado: admin.firestore.Timestamp.now(),
        },
        { merge: true }
      );
    espejoPublicado = actual;
    console.log(
      `[PAGOS] Espejo público actualizado → rapid=${rapidProduccionPublicada()} epayco=${EPAYCO_CFG.produccion} ` +
        `epaycoPaises=[${EPAYCO_CFG.paises.join(',')}] epaycoExcluir=[${EPAYCO_CFG.excluirPaises.join(',')}] mpPaises=${MP_PAISES.join(',')}`
    );
  } catch (e) {
    console.warn('[PAGOS] No pude publicar el espejo público:', e.message);
  }
}

function hostDeModo(modo) {
  return String(modo).toLowerCase() === 'live' ? RAPID_HOST_LIVE : RAPID_HOST_SANDBOX;
}

// Producción REAL de Rapid para la app: hace falta el interruptor RAPID_ACTIVO
// (Rapid quedó reemplazada por ePayco) Y que su config esté en producción.
function rapidProduccionPublicada() {
  return RAPID_ACTIVO && RAPID_CFG.produccion;
}

// Lee (o crea) `config_pagos/rapid` y deja RAPID_CFG actualizado.
async function refrescarConfigRapid({ forzar = false } = {}) {
  if (!forzar && Date.now() - rapidCfgLeido < PAGOS_TTL_MS) return RAPID_CFG;
  try {
    const ref = db.collection('config_pagos').doc('rapid');
    const doc = await ref.get();
    if (!doc.exists) {
      const base = {
        produccion: false,
        modo: 'sandbox',
        accessKey: RAPID_ACCESS_KEY,
        secretKey: RAPID_SECRET_KEY,
        pais: RAPID_PAIS,
        moneda: RAPID_MONEDA,
        webhookUrl: RAPID_WEBHOOK_URL,
        nota: 'produccion=false → SANDBOX (botón oculto en la app) · true → PRODUCCIÓN (botón visible). modo: sandbox|live',
        actualizado: admin.firestore.Timestamp.now(),
      };
      await ref.set(base, { merge: true });
      RAPID_CFG = { ...base, host: hostDeModo(base.modo) };
      rapidCfgLeido = Date.now();
      console.log('[PAGOS] config_pagos/rapid CREADA con los valores de sandbox');
      await publicarEspejoPasarelas();
      return RAPID_CFG;
    }
    const d = doc.data() || {};
    const produccion = aBool(d.produccion);
    const modo = String(d.modo || (produccion ? 'live' : 'sandbox')).toLowerCase();
    RAPID_CFG = {
      produccion,
      produccionCrudo: d.produccion === undefined ? '(falta el campo)' : String(d.produccion),
      produccionTipo: typeof d.produccion,
      modo,
      accessKey: String(d.accessKey || RAPID_ACCESS_KEY).trim(),
      secretKey: String(d.secretKey || RAPID_SECRET_KEY).trim(),
      pais: String(d.pais || RAPID_PAIS).trim(),
      moneda: String(d.moneda || RAPID_MONEDA).trim(),
      webhookUrl: String(d.webhookUrl || RAPID_WEBHOOK_URL).trim(),
      host: hostDeModo(modo),
    };
    rapidCfgLeido = Date.now();
    await publicarEspejoPasarelas();
  } catch (e) {
    console.error('[PAGOS] No pude leer config_pagos/rapid (uso respaldo):', e.message);
    rapidCfgLeido = Date.now() - PAGOS_TTL_MS + 10000; // reintenta en 10 s
  }
  return RAPID_CFG;
}

// Firma de un REQUEST a la API de Rapid (hex → base64, tal cual el SDK).
// Usa las llaves de RAPID_CFG (que vienen de Firestore, dinámicas).
function rapidFirmaRequest(method, path, body, salt, timestamp) {
  return Buffer.from(
    crypto
      .createHmac('sha256', RAPID_CFG.secretKey)
      .update(String(method || '').toLowerCase())
      .update(path)
      .update(salt)
      .update(String(timestamp))
      .update(RAPID_CFG.accessKey)
      .update(RAPID_CFG.secretKey)
      .update(body || '')
      .digest('hex')
  ).toString('base64');
}

// Firma de un WEBHOOK entrante (incluye la URL pública del webhook).
function rapidFirmaWebhook(url, salt, timestamp, rawBody) {
  return Buffer.from(
    crypto
      .createHmac('sha256', RAPID_CFG.secretKey)
      .update(url)
      .update(salt || '')
      .update(String(timestamp || ''))
      .update(RAPID_CFG.accessKey)
      .update(RAPID_CFG.secretKey)
      .update(rawBody || '')
      .digest('hex')
  ).toString('base64');
}

// Llamada autenticada a la API de Rapid. Devuelve el JSON completo y
// lanza error si el `status` no es SUCCESS.
async function rapidRequest(method, path, bodyObj) {
  await refrescarConfigRapid(); // garantiza llaves/host al día (cache 1 min)
  const salt = crypto.randomBytes(8).toString('hex');
  const timestamp = Math.round(Date.now() / 1000);
  const body = bodyObj ? JSON.stringify(bodyObj) : '';
  const signature = rapidFirmaRequest(method, path, body, salt, timestamp);
  const resp = await fetch(`https://${RAPID_CFG.host}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      salt,
      timestamp: String(timestamp),
      signature,
      access_key: RAPID_CFG.accessKey,
      idempotency: String(Date.now()),
    },
    body: body || undefined,
  });
  const txt = await resp.text();
  let json = null;
  try {
    json = JSON.parse(txt);
  } catch (_) {
    json = null;
  }
  const estado = json && json.status ? json.status.status : '';
  if (!json || estado !== 'SUCCESS') {
    const detalle =
      (json && json.status && (json.status.message || json.status.error_code)) ||
      String(txt).slice(0, 200);
    throw new Error(`Rapid ${resp.status}: ${detalle}`);
  }
  return json;
}

// ── GET /rapid/diag — comprueba que las credenciales funcionan ──
// Útil para verificar en 1 segundo: abrí esta URL en el navegador.
app.get('/rapid/diag', async (req, res) => {
  try {
    await refrescarConfigRapid({ forzar: req.query.refrescar === '1' });
    const json = await rapidRequest(
      'GET',
      `/v1/payment_methods/country?country=${RAPID_CFG.pais}&currency=${RAPID_CFG.moneda}`,
      null
    );
    res.json({
      ok: true,
      produccion: RAPID_CFG.produccion, // false = sandbox → botón oculto en la app
      // Diagnóstico: qué leyó EXACTAMENTE de Firestore (por si quedó como texto)
      produccionCrudo: RAPID_CFG.produccionCrudo,
      produccionTipo: RAPID_CFG.produccionTipo,
      modo: RAPID_CFG.modo,
      host: RAPID_CFG.host,
      pais: RAPID_CFG.pais,
      moneda: RAPID_CFG.moneda,
      webhook: RAPID_CFG.webhookUrl,
      accessKey: maskClave(RAPID_CFG.accessKey),
      secretKey: maskClave(RAPID_CFG.secretKey),
      config: 'config_pagos/rapid',
      metodosDisponibles: (json.data || []).map((m) => m.type),
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message, modo: RAPID_CFG.modo });
  }
});

// ── POST /rapid/crear-orden — crea el checkout hospedado ──
// Mismo contrato que /mp/crear-preferencia: responde { initPoint }.
app.post('/rapid/crear-orden', verificarTokenUsuario, async (req, res) => {
  const { planId } = req.body || {};
  const { uid } = req.user;
  const plan = PLANES_MP[planId];
  if (!plan) return res.status(400).json({ error: 'Plan inválido' });
  try {
    // Config al día desde Firestore (llaves, modo, país, moneda).
    await refrescarConfigRapid();
    // Precio en COP con la tasa del día (automática, cacheada 6 h).
    const tasa = await obtenerTasaUsdCop();
    const monto = montoCop(plan, tasa.valor);
    const json = await rapidRequest('POST', '/v1/checkout', {
      amount: monto,
      currency: RAPID_CFG.moneda,
      country: RAPID_CFG.pais,
      merchant_reference_id: `${uid}|${planId}`,
      description: plan.titulo,
      complete_payment_url: `${RAPID_VPS}/rapid/retorno`,
      error_payment_url: `${RAPID_VPS}/rapid/error`,
      cancel_payment_url: `${RAPID_VPS}/rapid/cancelado`,
      language: 'es',
    });
    const d = json.data || {};
    if (!d.redirect_url) throw new Error('Rapid no devolvió redirect_url');
    await db.collection('rapid_ordenes').doc(String(d.id)).set(
      {
        uid,
        planId,
        monto,
        moneda: RAPID_CFG.moneda,
        estado: d.status || 'NEW',
        modo: RAPID_CFG.modo,
        produccion: RAPID_CFG.produccion,
        creadoEn: admin.firestore.Timestamp.now(),
      },
      { merge: true }
    );
    console.log(
      `[RAPID] Checkout ${d.id} uid=${uid} plan=${planId} monto=${monto} ${RAPID_CFG.moneda} (${RAPID_CFG.modo}, tasa ${tasa.valor.toFixed(2)})`
    );
    res.json({ initPoint: d.redirect_url, checkoutId: d.id });
  } catch (e) {
    console.error('[RAPID] Error crear checkout:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── Busca en Rapid los pagos ACREDITADOS y activa las membresías ──
// Es la vía más confiable: no depende de parámetros en la URL de retorno ni
// del webhook. La activación es idempotente (`pago_<paymentId>`), así que
// llamarla varias veces NO extiende la membresía dos veces.
//   · uidFiltro   → sólo los pagos de ese usuario (ej: 'PZTs3w9…').
//   · planFiltro  → sólo ese plan (opcional).
//   · desdeSeg    → ventana de tiempo (0 = sin límite).
async function rapidActivarPagos(uidFiltro, planFiltro, desdeSeg) {
  const json = await rapidRequest('GET', '/v1/payments?limit=50', null);
  const desde = desdeSeg ? Math.floor(Date.now() / 1000) - desdeSeg : 0;
  const activados = [];
  for (const p of json.data || []) {
    const ref = String(p.merchant_reference_id || '');
    if (!ref.includes('|')) continue;
    if (p.refunded === true) continue;                       // devuelto → no cuenta
    if (!(p.paid === true || p.status === 'CLO')) continue;  // sólo acreditados
    if (uidFiltro && !ref.startsWith(`${uidFiltro}|`)) continue;
    if (planFiltro && ref !== `${uidFiltro}|${planFiltro}`) continue;
    if (desde && Number(p.created_at || 0) < desde) continue;

    const [uid, planId] = ref.split('|');
    const fecha = await activarMembresia(uid, planId, 'Rapid', `pago_${p.id}`, 'rapid_ordenes');
    if (fecha) {
      activados.push({ uid, planId, paymentId: p.id });
      await db.collection('rapid_ordenes').doc(String(p.checkout_id || p.id)).set(
        {
          uid,
          planId,
          paymentId: p.id,
          estado: 'PAGADO',
          pagadoEn: admin.firestore.Timestamp.now(),
        },
        { merge: true }
      );
    }
  }
  return activados;
}

// ── POST /rapid/verificar — la app consulta si el pago ya se acreditó ──
// Lo usa el botón "Verificar estado". Devuelve { pagado, activados, planes }.
//
// ⚠️ El APK instalado llama SIEMPRE a este endpoint (aunque el cliente haya
//    pagado con ePayco), así que acá verificamos **las dos pasarelas**:
//    Rapid y ePayco. Así un pago de ePayco que quedó "pendiente" en la app se
//    activa al tocar "Verificar estado", sin necesidad de actualizar la app.
app.post('/rapid/verificar', verificarTokenUsuario, async (req, res) => {
  const { uid } = req.user;
  const planId = (req.body && req.body.planId) || '';
  try {
    let activados = await rapidActivarPagos(uid, planId, 0);
    // Si no había nada de ESE plan, buscamos cualquier pago acreditado del
    // usuario (pagó otro plan, o quedó pendiente de una compra anterior).
    if (!activados.length && planId) {
      activados = await rapidActivarPagos(uid, '', 0);
    }

    // ePayco (misma idea: primero ese plan, después cualquiera).
    let epayco = { activados: [], yaActivos: [] };
    try {
      epayco = await epaycoVerificarPagos(uid, planId);
      if (!epayco.activados.length && !epayco.yaActivos.length && planId) {
        epayco = await epaycoVerificarPagos(uid, '');
      }
    } catch (e) {
      console.warn('[EPAYCO] Verificar (desde /rapid/verificar):', e.message);
    }

    // Mercado Pago (igual: primero ese plan, después cualquiera).
    let mp = { activados: [], yaActivos: [] };
    try {
      mp = await mpVerificarPagos(uid, planId);
      if (!mp.activados.length && !mp.yaActivos.length && planId) {
        mp = await mpVerificarPagos(uid, '');
      }
    } catch (e) {
      console.warn('[MP] Verificar (desde /rapid/verificar):', e.message);
    }

    const planes = [
      ...activados.map((a) => a.planId),
      ...epayco.activados.map((a) => a.planId),
      ...epayco.yaActivos.map((a) => a.planId),
      ...mp.activados.map((a) => a.planId),
      ...mp.yaActivos.map((a) => a.planId),
    ];
    const pagado = planes.length > 0;
    console.log(
      `[VERIFICAR] uid=${uid} plan=${planId || 'cualquiera'} → rapid=${activados.length} ` +
        `epayco=${epayco.activados.length} (ya ${epayco.yaActivos.length}) ` +
        `mp=${mp.activados.length} (ya ${mp.yaActivos.length}) pagado=${pagado}`
    );
    res.json({
      ok: true,
      pagado,
      activados: activados.length + epayco.activados.length + mp.activados.length,
      planes,
      rapid: { activados: activados.length },
      epayco: {
        activados: epayco.activados.length,
        yaActivos: epayco.yaActivos.length,
        ordenes: [...epayco.activados, ...epayco.yaActivos],
      },
      mercadopago: {
        activados: mp.activados.length,
        yaActivos: mp.yaActivos.length,
        pagos: [...mp.activados, ...mp.yaActivos],
      },
    });
  } catch (e) {
    console.error('[RAPID] Error verificar:', e.message);
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ── GET /rapid/retorno — el cliente volvió del checkout ──
// Consulta el estado real en Rapid y activa la membresía (idempotente).
// Al final vuelve a la app con el deep link que ya entiende el WebView.
app.get('/rapid/retorno', async (req, res) => {
  try {
    const q = req.query || {};
    const candidato = String(
      q.checkout_id || q.checkoutId || q.rapyd_checkout || q.token ||
      q.payment_id || q.paymentId || q.id || ''
    );
    console.log(`[RAPID] Retorno query=${JSON.stringify(q)}`);

    // (1) Rapid devolvió el id del PAGO → verificamos directo.
    if (candidato.startsWith('payment_')) {
      try {
        const pj = await rapidRequest('GET', `/v1/payments/${candidato}`, null);
        const p = pj.data || {};
        const ref = String(p.merchant_reference_id || '');
        console.log(
          `[RAPID] Retorno pago=${candidato} estado=${p.status} paid=${p.paid} ref=${ref}`
        );
        if ((p.paid === true || p.status === 'CLO') && ref.includes('|')) {
          const [u, pl] = ref.split('|');
          await activarMembresia(u, pl, 'Rapid', `pago_${p.id}`, 'rapid_ordenes');
          return res.redirect('starkgo://pago/exitoso');
        }
      } catch (e) {
        console.error('[RAPID] Retorno: no pude leer el pago:', e.message);
      }
    }

    // (2) Si trae el id del CHECKOUT, consultamos su estado.
    const checkoutId = candidato.startsWith('checkout_') ? candidato : '';
    if (checkoutId) {
      let uid = '';
      let planId = '';
      const doc = await db.collection('rapid_ordenes').doc(checkoutId).get();
      if (doc.exists) {
        uid = doc.data().uid || '';
        planId = doc.data().planId || '';
      }
      let pagoId = null;
      let pagado = false;
      try {
        const json = await rapidRequest('GET', `/v1/checkout/${checkoutId}`, null);
        const d = json.data || {};
        const pago = d.payment || {};
        pagoId = pago.id || null;
        pagado =
          d.status === 'CLO' ||
          pago.status === 'CLO' ||
          pago.status === 'ACT' ||
          pago.paid === true;
        if (pago.merchant_reference_id) {
          const partes = String(pago.merchant_reference_id).split('|');
          if (!uid) uid = partes[0] || '';
          if (!planId) planId = partes[1] || '';
        }
        console.log(
          `[RAPID] Retorno checkout=${checkoutId} estado=${d.status} pago=${pago.status} paid=${pago.paid} ref=${pago.merchant_reference_id || ''}`
        );
      } catch (e) {
        console.error('[RAPID] No se pudo verificar el checkout:', e.message);
      }
      if (pagado && uid && planId) {
        await activarMembresia(
          uid,
          planId,
          'Rapid',
          `pago_${pagoId || checkoutId}`,
          'rapid_ordenes'
        );
        await db.collection('rapid_ordenes').doc(checkoutId).set(
          {
            estado: 'PAGADO',
            paymentId: pagoId,
            pagadoEn: admin.firestore.Timestamp.now(),
          },
          { merge: true }
        );
        return res.redirect('starkgo://pago/exitoso');
      }
    }

    // (3) RESPALDO: el cliente ACABA de pagar. Si Rapid no nos manda el id en
    //     la URL (ni el webhook está configurado), buscamos el pago acreditado
    //     de las últimas 6 horas y lo activamos. Es idempotente por paymentId.
    const activados = await rapidActivarPagos('', '', 6 * 3600);
    if (activados.length) {
      console.log(`[RAPID] Retorno: activado por respaldo → ${JSON.stringify(activados)}`);
      return res.redirect('starkgo://pago/exitoso');
    }
    return res.redirect('starkgo://pago/pendiente');
  } catch (e) {
    console.error('[RAPID] Error retorno:', e.message);
    return res.redirect('starkgo://pago/fallido');
  }
});

// ── GET /rapid/error y /rapid/cancelado — vuelven a la app ──
app.get('/rapid/error', (req, res) => res.redirect('starkgo://pago/fallido'));
app.get('/rapid/cancelado', (req, res) => res.redirect('starkgo://pago/pendiente'));

// ── POST /rapid/webhook — notificación de Rapid (respaldo) ──
// Verifica la firma (sobre el body CRUDO) y activa la membresía.
app.post('/rapid/webhook', async (req, res) => {
  try {
    const salt = req.headers.salt;
    const timestamp = req.headers.timestamp;
    const firma = req.headers.signature;
    const crudo = req.rawBody
      ? req.rawBody.toString('utf8')
      : JSON.stringify(req.body || {});

    await refrescarConfigRapid();

    const esperada = rapidFirmaWebhook(RAPID_CFG.webhookUrl, salt, timestamp, crudo);
    if (firma && esperada !== firma) {
      console.warn(
        '[RAPID] ⚠️ Firma de webhook inválida. Verificá que la URL configurada en el panel de ' +
          'Rapid sea exactamente ' + RAPID_CFG.webhookUrl
      );
      return res.sendStatus(401);
    }

    const tipo = (req.body && req.body.type) || '';
    const data = (req.body && req.body.data) || {};
    const ref = String(data.merchant_reference_id || '');
    const estado = String(data.status || '');
    console.log(
      `[RAPID] Webhook tipo=${tipo} estado=${estado} ref=${ref} id=${data.id || ''}`
    );

    const pagado = tipo === 'PAYMENT_COMPLETED' || estado === 'CLO' || data.paid === true;
    if (pagado && ref.includes('|')) {
      const [uid, planId] = ref.split('|');
      const pagoId = data.id || data.payment_id || null;
      await activarMembresia(
        uid,
        planId,
        'Rapid',
        pagoId ? `pago_${pagoId}` : null,
        'rapid_ordenes'
      );
    }
    res.sendStatus(200);
  } catch (e) {
    console.error('[RAPID] Error webhook:', e.message);
    res.sendStatus(500);
  }
});

console.log(
  `[RAPID] Módulo cargado. Config dinámica en Firestore: config_pagos/rapid ` +
    `(respaldo: modo=${RAPID_MODE}, webhook=${RAPID_WEBHOOK_URL})`
);
// Lee la config real (y crea el documento si todavía no existe).
refrescarConfigRapid({ forzar: true })
  .then((c) =>
    console.log(
      `[RAPID] Config → produccion=${c.produccion} (crudo=${c.produccionCrudo}, tipo=${c.produccionTipo}) ` +
        `modo=${c.modo} host=${c.host} accessKey=${maskClave(c.accessKey)}`
    )
  )
  .catch((e) => console.error('[RAPID] Config:', e.message));

console.log(
  `[EPAYCO] Módulo cargado. Config dinámica en Firestore: config_pagos/epayco ` +
    `(respaldo: modo=${EPAYCO_MODE}, checkout=${EPAYCO_CHECKOUT_URL})`
);
// Lee la config real (y crea el documento EN PRUEBAS si todavía no existe,
// así el botón queda oculto hasta que cargues las llaves y lo pongas en true).
refrescarConfigEpayco({ forzar: true })
  .then((c) =>
    console.log(
      `[EPAYCO] Config → produccion=${c.produccion} (crudo=${c.produccionCrudo}) ` +
        `modo=${c.modo} custIdCliente=${c.custIdCliente || '(falta)'} ` +
        `pKey=${c.pKey ? maskClave(c.pKey) : '(falta)'}`
    )
  )
  .catch((e) => console.error('[EPAYCO] Config:', e.message));

// ════════════════════════════════════════════════════════════════
//  PAYPAL - Renovar Membresía
//
//  ⚠️  CONFIGURA TUS CREDENCIALES AQUÍ (o con variables de entorno).
//      PAYPAL_MODE = 'live' (cobros reales) | 'sandbox' (pruebas)
//
//  Flujo (igual que Mercado Pago):
//    1. La app llama POST /paypal/crear-orden  → devuelve { initPoint }
//    2. La app abre el WebView con esa URL (paypal.com)
//    3. PayPal redirige a GET /paypal/retorno  → captura la orden,
//       activa la membresía y vuelve a la app con starkgo://pago/...
//    4. PayPal además notifica POST /paypal/webhook (respaldo).
// ════════════════════════════════════════════════════════════════
const PAYPAL_CLIENT_ID = credencial('PAYPAL_CLIENT_ID');
const PAYPAL_CLIENT_SECRET = credencial('PAYPAL_CLIENT_SECRET');
if (!PAYPAL_CLIENT_ID || !PAYPAL_CLIENT_SECRET) {
  console.warn(
    '[PAYPAL] ⚠️ Faltan PAYPAL_CLIENT_ID / PAYPAL_CLIENT_SECRET. ' +
      'Ponelas en variables de entorno del VPS o en functions/credenciales.local.json.'
  );
}
const PAYPAL_MODE = (process.env.PAYPAL_MODE || 'live').toLowerCase(); // 'live' | 'sandbox'
const PAYPAL_API = PAYPAL_MODE === 'sandbox'
  ? 'https://api-m.sandbox.paypal.com'
  : 'https://api-m.paypal.com';
// URL pública del VPS: PayPal redirige aquí después del pago.
const PAYPAL_VPS = process.env.PAYPAL_VPS_URL || 'http://5.161.88.42:3000';

// ── Token OAuth2 de PayPal (se cachea ~1 hora) ────────────────────
let paypalTokenCache = { valor: null, expira: 0 };
async function paypalAccessToken() {
  if (paypalTokenCache.valor && Date.now() < paypalTokenCache.expira) {
    return paypalTokenCache.valor;
  }
  const auth = Buffer.from(`${PAYPAL_CLIENT_ID}:${PAYPAL_CLIENT_SECRET}`).toString('base64');
  const resp = await fetch(`${PAYPAL_API}/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  if (!resp.ok) {
    throw new Error(`PayPal OAuth ${resp.status}: ${await resp.text()}`);
  }
  const data = await resp.json();
  paypalTokenCache = {
    valor: data.access_token,
    expira: Date.now() + (data.expires_in - 600) * 1000, // renueva 10 min antes
  };
  return paypalTokenCache.valor;
}

// ── Activa/renueva la membresía del usuario (misma lógica que MP) ──
// `ordenId` (opcional) evita activar dos veces la misma compra: PayPal/Rapid
// pueden llamar tanto al retorno como al webhook de la misma orden.
async function activarMembresia(uid, planId, fuente, ordenId, coleccionOrdenes) {
  const plan = PLANES_MP[planId];
  if (!uid || !plan) return null;

  if (ordenId) {
    const refOrden = db.collection(coleccionOrdenes || 'paypal_ordenes').doc(ordenId);
    const ya = await refOrden.get();
    if (ya.exists && ya.data().activado) {
      console.log(`[${fuente}] Orden ${ordenId} ya activada, se omite`);
      return null;
    }
    await refOrden.set(
      { uid, planId, fuente, activado: true, fecha: admin.firestore.Timestamp.now() },
      { merge: true }
    );
  }

  const userRef = db.collection('user').doc(uid);
  const userDoc = await userRef.get();
  const tsActual = userDoc.data()?.fechaVencimiento?.toDate();
  const base = (tsActual && tsActual > new Date()) ? tsActual : new Date();
  const nuevaFecha = new Date(base);
  nuevaFecha.setMonth(nuevaFecha.getMonth() + plan.meses);

  await userRef.update({
    fechaVencimiento: admin.firestore.Timestamp.fromDate(nuevaFecha),
    planMembresia: planId,
    activo: true,
    plan: {
      tipo: plan.tipo,
      nombre: plan.titulo,
      meses: plan.meses,
      precio: plan.precio,
      actualizado: admin.firestore.Timestamp.now(),
    },
  });
  console.log(`[${fuente}] ✅ uid=${uid} renovado hasta ${nuevaFecha.toISOString()} plan=${planId} tipo=${plan.tipo}`);
  return nuevaFecha;
}

// ── Sesión firmada (HMAC) para el checkout hospedado ──
// Así la página de checkout puede crear/capturar órdenes sin exponer el
// token de Firebase: la firma incluye uid + planId + expiración.
const crypto = require('crypto');
const PAYPAL_SESSION_SECRET = process.env.PAYPAL_SESSION_SECRET || PAYPAL_CLIENT_SECRET;

function firmarSesion(uid, planId, ttlMs) {
  const exp = Date.now() + (ttlMs || 30 * 60 * 1000); // 30 min
  const payload = Buffer.from(JSON.stringify({ uid, planId, exp })).toString('base64url');
  const sig = crypto.createHmac('sha256', PAYPAL_SESSION_SECRET).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

function verificarSesion(token) {
  if (!token || String(token).indexOf('.') === -1) return null;
  const partes = String(token).split('.');
  if (partes.length !== 2) return null;
  const esperado = crypto.createHmac('sha256', PAYPAL_SESSION_SECRET).update(partes[0]).digest('base64url');
  if (partes[1] !== esperado) return null;
  try {
    const data = JSON.parse(Buffer.from(partes[0], 'base64url').toString('utf8'));
    if (!data.exp || Date.now() > data.exp) return null;
    return data;
  } catch (e) {
    return null;
  }
}

// ── POST /paypal/crear-orden — devuelve la URL del checkout hospedado ──
// Mismo contrato que /mp/crear-preferencia: responde { initPoint, ... }.
// La URL apunta a NUESTRA página /paypal/checkout (Smart Buttons con tarjeta).
app.post('/paypal/crear-orden', verificarTokenUsuario, async (req, res) => {
  const { planId } = req.body;
  const { uid } = req.user;
  const plan = PLANES_MP[planId];
  if (!plan) return res.status(400).json({ error: 'Plan inválido' });
  const s = firmarSesion(uid, planId);
  const url = `${PAYPAL_VPS}/paypal/checkout?s=${encodeURIComponent(s)}`;
  console.log(`[PP] Sesión de checkout uid=${uid} plan=${planId} modo=${PAYPAL_MODE}`);
  res.json({ initPoint: url, checkoutUrl: url, orderId: null });
});

// ── GET /paypal/retorno — PayPal redirige aquí tras aprobar el pago ──
// Captura la orden, activa la membresía y vuelve a la app (deep link).
app.get('/paypal/retorno', async (req, res) => {
  const orderId = req.query.token; // PayPal envía ?token=<orderId>&PayerID=...
  try {
    if (!orderId) return res.redirect('starkgo://pago/fallido');
    const token = await paypalAccessToken();
    const resp = await fetch(`${PAYPAL_API}/v2/checkout/orders/${orderId}/capture`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    });
    let resultado = await resp.json();
    let status = resultado.status;
    // Si la captura falló (p. ej. la orden ya se capturó en un retorno previo),
    // consultamos la orden para conocer su estado real.
    if (!resp.ok) {
      const det = await fetch(`${PAYPAL_API}/v2/checkout/orders/${orderId}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      resultado = await det.json();
      status = resultado.status || status;
    }
    console.log(`[PP] Retorno orden=${orderId} status=${status}`);
    if (status === 'COMPLETED') {
      const pu = (resultado.purchase_units || [])[0] || {};
      const cap = (pu.payments?.captures || [])[0] || {};
      const custom = String(cap.custom_id || pu.custom_id || '');
      const [uid, planId] = custom.split('|');
      const capId = cap.id || orderId; // mismo id que usará el webhook (idempotencia)
      await activarMembresia(uid, planId, 'PP', capId);
      return res.redirect('starkgo://pago/exitoso');
    }
    if (status === 'PENDING') return res.redirect('starkgo://pago/pendiente');
    return res.redirect('starkgo://pago/fallido');
  } catch (e) {
    console.error('[PP] Error retorno:', e.message);
    res.redirect('starkgo://pago/fallido');
  }
});

// ── GET /paypal/cancelado — el usuario canceló el pago en PayPal ──
app.get('/paypal/cancelado', (req, res) => res.redirect('starkgo://pago/fallido'));

// ── POST /paypal/diag — diagnóstico del checkout (para depurar tarjeta) ──
app.post('/paypal/diag', (req, res) => {
  const ses = verificarSesion(req.query.s);
  if (!ses) return res.sendStatus(401);
  console.log('[PP][DIAG]', JSON.stringify(req.body || {}));
  res.sendStatus(200);
});

// ── POST /paypal/webhook — confirmación asíncrona de PayPal (respaldo) ──
app.post('/paypal/webhook', async (req, res) => {
  try {
    const evento = req.body || {};
    if (evento.event_type === 'PAYMENT.CAPTURE.COMPLETED') {
      const recurso = evento.resource || {};
      const custom = String(recurso.custom_id || '');
      const [uid, planId] = custom.split('|');
      await activarMembresia(uid, planId, 'PP-webhook', recurso.id);
    }
    res.sendStatus(200);
  } catch (e) {
    console.error('[PP] Error webhook:', e.message);
    res.sendStatus(500);
  }
});

console.log(`[PP] PayPal cargado (modo=${PAYPAL_MODE})`);

// ── Página de checkout hospedada (PayPal Smart Buttons + opción tarjeta) ──
// Se sirve al WebView de la app. Muestra los botones de PayPal y, si la cuenta
// tiene habilitado "Advanced Credit and Debit Card Payments" (ACDC), también el
// botón "Tarjeta de débito o crédito" que permite pagar SIN iniciar sesión.
// No contiene plantillas literales `${}` para evitar conflictos con el backend.
const PAYPAL_CHECKOUT_HTML = [
  '<!DOCTYPE html>',
  '<html lang="es">',
  '<head>',
  '<meta charset="utf-8" />',
  '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />',
  '<title>Pago seguro - StarkGo</title>',
  '<style>',
  '  * { box-sizing: border-box; }',
  '  html { color-scheme: only light; }',
  '  html, body { margin: 0; padding: 0; background: #0F172A; color: #ffffff;',
  '    font-family: -apple-system, Segoe UI, Roboto, Helvetica, sans-serif; }',
  '  .wrap { max-width: 460px; margin: 0 auto; padding: 22px 18px 40px; }',
  '  .info { background: #1E293B; border: 1px solid rgba(255,255,255,0.12);',
  '    border-radius: 16px; padding: 16px 18px; margin-bottom: 14px; }',
  '  .titulo { font-size: 17px; font-weight: 800; margin: 0 0 4px; color: #ffffff; }',
  '  .precio { color: #22E0C6; font-size: 15px; font-weight: 800; margin: 0 0 4px; }',
  '  .sub { color: rgba(255,255,255,0.78); font-size: 12.5px; margin: 0; }',
  '  .panel { background: #ffffff; border-radius: 16px; padding: 16px; }',
  '  .lbl { display: block; color: #334155; font-size: 12.5px; font-weight: 700; margin: 0 0 6px; }',
  '  .field { height: 46px; border: 1px solid #CBD5E1; border-radius: 10px;',
  '    background: #FFFFFF; padding: 10px; margin-bottom: 12px; overflow: hidden; }',
  '  .row { display: flex; gap: 10px; }',
  '  .row > div { flex: 1; }',
  '  .btn-pay { width: 100%; height: 50px; border: 0; border-radius: 12px;',
  '    background: linear-gradient(135deg, #0070BA, #003087); color: #FFFFFF;',
  '    font-size: 15px; font-weight: 800; cursor: pointer; margin-top: 4px; }',
  '  .btn-pay:disabled { opacity: 0.6; }',
  '  .sep { display: flex; align-items: center; gap: 10px; color: #94A3B8;',
  '    font-size: 12px; margin: 16px 0 12px; }',
  '  .sep::before, .sep::after { content: ""; flex: 1; height: 1px; background: #E2E8F0; }',
  '  #paypal-buttons { min-height: 80px; background: #ffffff; }',
  '  #msg { display: none; margin-top: 14px; color: #FCA5A5; font-size: 12.5px; }',
  '  .nota { color: rgba(255,255,255,0.62); font-size: 11.5px; margin: 16px 0 0; line-height: 1.5; }',
  '</style>',
  '</head>',
  '<body>',
  '<div class="wrap">',
  '  <div class="info">',
  '    <p class="titulo">__TITULO__</p>',
  '    <p class="precio">__PRECIO__</p>',
  '    <p class="sub">Paga con tarjeta o con tu cuenta PayPal.</p>',
  '  </div>',
  '  <div class="panel">',
  '    <div id="card-form" style="display:none">',
  '      <label class="lbl">Numero de tarjeta</label>',
  '      <div id="cf-number" class="field"></div>',
  '      <div class="row">',
  '        <div>',
  '          <label class="lbl">Vencimiento</label>',
  '          <div id="cf-expiry" class="field"></div>',
  '        </div>',
  '        <div>',
  '          <label class="lbl">CVC</label>',
  '          <div id="cf-cvv" class="field"></div>',
  '        </div>',
  '      </div>',
  '      <button id="cf-pay" class="btn-pay">Pagar ahora</button>',
  '      <div class="sep">o paga con PayPal</div>',
  '    </div>',
  '    <div id="paypal-buttons"></div>',
  '  </div>',
  '  <div id="msg">No se pudo cargar el pago. Revisa tu conexion e intentalo de nuevo.</div>',
  '  <p class="nota">Pago procesado por PayPal. Con tarjeta no necesitas iniciar sesion.</p>',
  '</div>',
  '<script src="https://www.paypal.com/sdk/js?client-id=__CLIENT_ID__&components=buttons,card-fields&enable-funding=card&disable-funding=credit&currency=USD&intent=capture"></script>',
  '<script>',
  '  var S = "__TOKEN__";',
  '  function mostrarError(detalle) {',
  '    var m = document.getElementById("msg");',
  '    m.style.display = "block";',
  '    m.textContent = "No se pudo completar el pago." + (detalle ? " (" + detalle + ")" : " Intenta de nuevo.");',
  '    try { fetch("/paypal/diag?s=" + encodeURIComponent(S), { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ evento: "error", detalle: String(detalle || "") }) }); } catch (e) {}',
  '  }',
  '  function pedirOrden(ruta) {',
  '    return fetch(ruta + "?s=" + encodeURIComponent(S), { method: "POST" })',
  '      .then(function (r) { return r.json(); })',
  '      .then(function (d) { if (!d.id) throw new Error(d.error || "sin orden"); return d.id; });',
  '  }',
  '  function crearOrden() { return pedirOrden("/paypal/orden-js"); }',
  '  function crearOrdenCard() { return pedirOrden("/paypal/orden-card-js"); }',
  '  function capturar(orderID) {',
  '    return fetch("/paypal/capturar?s=" + encodeURIComponent(S), {',
  '      method: "POST",',
  '      headers: { "Content-Type": "application/json" },',
  '      body: JSON.stringify({ orderID: orderID })',
  '    }).then(function (r) { return r.json(); });',
  '  }',
  '  function ir(destino) { window.location.href = "starkgo://pago/" + destino; }',
  '  function aprobar(orderID) {',
  '    return capturar(orderID).then(function (res) {',
  '      if (res && res.status === "COMPLETED") ir("exitoso");',
  '      else if (res && res.status === "PENDING") ir("pendiente");',
  '      else ir("fallido");',
  '    }).catch(function () { ir("fallido"); });',
  '  }',
  '  var estiloCampos = {',
  '    input: { color: "#0F172A", "font-size": "16px", "font-family": "Arial, sans-serif" },',
  '    ":focus": { color: "#0F172A" },',
  '    ".invalid": { color: "#B91C1C" }',
  '  };',
  '  var cardFields = null;',
  '  var camposListos = false;',
  '  if (window.paypal && paypal.CardFields) {',
  '    try {',
  '      cardFields = paypal.CardFields({',
  '        createOrder: crearOrdenCard,',
  '        onApprove: function (data) { return aprobar(data.orderID); },',
  '        onError: function (err) { mostrarError(err && err.message ? err.message : ""); },',
  '        style: estiloCampos',
  '      });',
  '    } catch (e) { cardFields = null; }',
  '  }',
  '  if (cardFields && cardFields.isEligible && cardFields.isEligible()) {',
  '    try {',
  '      cardFields.NumberField().render("#cf-number");',
  '      cardFields.ExpiryField().render("#cf-expiry");',
  '      cardFields.CVVField().render("#cf-cvv");',
  '      document.getElementById("card-form").style.display = "block";',
  '      document.getElementById("cf-pay").addEventListener("click", function () {',
  '        var b = this; b.disabled = true; b.textContent = "Procesando...";',
  '        cardFields.submit().catch(function (err) { b.disabled = false; b.textContent = "Pagar ahora"; mostrarError(err && err.message ? err.message : ""); });',
  '      });',
  '      camposListos = true;',
  '    } catch (e) { camposListos = false; }',
  '  }',
  '  try {',
  '    fetch("/paypal/diag?s=" + encodeURIComponent(S), { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ evento: "init", paypal: !!window.paypal, cardFields: !!(window.paypal && paypal.CardFields), cardEligible: (cardFields && cardFields.isEligible) ? cardFields.isEligible() : null, buttons: !!(window.paypal && paypal.Buttons), camposListos: camposListos }) });',
  '  } catch (e) {}',
  '  if (window.paypal && paypal.Buttons) {',
  '    paypal.Buttons({',
  '      style: { layout: "vertical", shape: "pill", label: "paypal", height: 46 },',
  '      createOrder: crearOrden,',
  '      onApprove: function (data) { return aprobar(data.orderID); },',
  '      onCancel: function () { ir("fallido"); },',
  '      onError: function (err) { mostrarError(err && err.message ? err.message : ""); }',
  '    }).render("#paypal-buttons");',
  '  } else if (!camposListos) {',
  '    mostrarError();',
  '  }',
  '</script>',
  '</body>',
  '</html>'
].join('\n');

// ── GET /paypal/checkout — sirve la página con los botones de PayPal ──
app.get('/paypal/checkout', (req, res) => {
  const ses = verificarSesion(req.query.s);
  if (!ses) return res.status(401).send('Sesión de pago inválida o expirada.');
  const plan = PLANES_MP[ses.planId];
  if (!plan) return res.status(400).send('Plan inválido.');
  const html = PAYPAL_CHECKOUT_HTML
    .replace('__CLIENT_ID__', () => PAYPAL_CLIENT_ID)
    .replace('__TITULO__', () => plan.titulo)
    .replace('__PRECIO__', () => '$' + plan.precio + ' USD')
    .replace('__TOKEN__', () => String(req.query.s));
  res.set('Content-Type', 'text/html; charset=utf-8').send(html);
});

// ── Helper: crea una orden de PayPal para la sesión ──
// `conCard=true` añade payment_source.card con experience_context, que PayPal
// EXIGE para Card Fields (tarjeta sin login) y para el reto 3D Secure.
async function crearOrdenPaypal(ses, conCard) {
  const plan = PLANES_MP[ses.planId];
  if (!plan) throw new Error('Plan inválido');
  const token = await paypalAccessToken();
  const body = {
    intent: 'CAPTURE',
    purchase_units: [
      {
        amount: { currency_code: 'USD', value: plan.precio.toFixed(2) },
        description: plan.titulo,
        custom_id: `${ses.uid}|${ses.planId}`,
        invoice_id: `${ses.uid}-${ses.planId}-${Date.now()}`,
      },
    ],
  };
  if (conCard) {
    body.payment_source = {
      card: {
        experience_context: {
          brand_name: 'StarkGo',
          locale: 'es-ES',
          shipping_preference: 'NO_SHIPPING',
          user_action: 'PAY_NOW',
          return_url: `${PAYPAL_VPS}/paypal/retorno-card`,
          cancel_url: `${PAYPAL_VPS}/paypal/cancelado`,
        },
      },
    };
  }
  const resp = await fetch(`${PAYPAL_API}/v2/checkout/orders`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const orden = await resp.json();
  if (!resp.ok) {
    console.error(`[PP] Error crear orden (card=${!!conCard}):`, JSON.stringify(orden));
    throw new Error('Error al crear orden');
  }
  console.log(`[PP] Orden creada ${orden.id} (card=${!!conCard}) uid=${ses.uid} plan=${ses.planId}`);
  return orden.id;
}

// ── POST /paypal/orden-js — orden para los botones de PayPal ──
app.post('/paypal/orden-js', async (req, res) => {
  const ses = verificarSesion(req.query.s);
  if (!ses) return res.status(401).json({ error: 'sesión inválida' });
  try {
    const id = await crearOrdenPaypal(ses, false);
    res.json({ id });
  } catch (e) {
    console.error('[PP] Error orden-js:', e.message);
    res.status(500).json({ error: 'Error al crear orden' });
  }
});

// ── POST /paypal/orden-card-js — orden para Card Fields (tarjeta) ──
app.post('/paypal/orden-card-js', async (req, res) => {
  const ses = verificarSesion(req.query.s);
  if (!ses) return res.status(401).json({ error: 'sesión inválida' });
  try {
    const id = await crearOrdenPaypal(ses, true);
    res.json({ id });
  } catch (e) {
    console.error('[PP] Error orden-card-js:', e.message);
    res.status(500).json({ error: 'Error al crear orden' });
  }
});

// ── Helper: captura una orden y activa la membresía. Devuelve el status ──
async function capturarOrdenPaypal(orderID, uidFallback, planIdFallback) {
  const token = await paypalAccessToken();
  const resp = await fetch(`${PAYPAL_API}/v2/checkout/orders/${orderID}/capture`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  });
  let resultado = await resp.json();
  let status = resultado.status;
  if (!resp.ok) {
    const det = await fetch(`${PAYPAL_API}/v2/checkout/orders/${orderID}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    resultado = await det.json();
    status = resultado.status || status;
    console.error(`[PP] Captura con error orden=${orderID}:`, JSON.stringify(resultado).slice(0, 400));
  }
  console.log(`[PP] Captura orden=${orderID} status=${status}`);
  if (status === 'COMPLETED') {
    const pu = (resultado.purchase_units || [])[0] || {};
    const cap = (pu.payments?.captures || [])[0] || {};
    const custom = String(cap.custom_id || pu.custom_id || `${uidFallback}|${planIdFallback}`);
    const [uid, planId] = custom.split('|');
    await activarMembresia(uid, planId, 'PP-js', cap.id || orderID);
  }
  return status;
}

// ── POST /paypal/capturar — captura la orden (Card Fields / botones) ──
app.post('/paypal/capturar', async (req, res) => {
  const ses = verificarSesion(req.query.s);
  if (!ses) return res.status(401).json({ error: 'sesión inválida' });
  const orderID = (req.body && req.body.orderID) || req.query.orderID;
  if (!orderID) return res.status(400).json({ error: 'Falta orderID' });
  try {
    const status = await capturarOrdenPaypal(orderID, ses.uid, ses.planId);
    res.json({ status });
  } catch (e) {
    console.error('[PP] Error capturar:', e.message);
    res.status(500).json({ error: 'Error al capturar' });
  }
});

// ── GET /paypal/retorno-card — retorno tras 3D Secure (Card Fields) ──
// PayPal redirige aquí con ?token=<orderId> cuando la tarjeta requiere 3DS.
app.get('/paypal/retorno-card', async (req, res) => {
  const orderID = req.query.token;
  try {
    if (!orderID) return res.redirect('starkgo://pago/fallido');
    const status = await capturarOrdenPaypal(orderID, '', '');
    if (status === 'COMPLETED') return res.redirect('starkgo://pago/exitoso');
    if (status === 'PENDING') return res.redirect('starkgo://pago/pendiente');
    return res.redirect('starkgo://pago/fallido');
  } catch (e) {
    console.error('[PP] Error retorno-card:', e.message);
    res.redirect('starkgo://pago/fallido');
  }
});

console.log('[PP] Checkout hospedado listo en /paypal/checkout');

// ════════════════════════════════════════════════════════════════
//  FACTURACION AUTOMATICA + COBROS STARLINKS
//  ⚠️  MOVIDO A mensajes.js (puerto 3001)
//  Este servidor (index.js) ya no maneja los mensajes automáticos.
//  Ver functions/mensajes.js para toda la lógica de:
//    - Recordatorios de pago (clientes generales)
//    - Pasar a mora
//    - Corte de servicio
//    - Cobros automáticos Starlinks
// ════════════════════════════════════════════════════════════════

const cron = require('node-cron');
const https = require('https');
const http  = require('http');



// ════════════════════════════════════════════════════════════════
//  CONSUMO — Tracking de megas cada 30 minutos
//
//  Colecciones Firestore que se crean automáticamente:
//    consumo_snapshots/{clienteId}_last    → último valor crudo de MikroTik
//    consumo_mensual/{clienteId}_YYYY-MM   → acumulado del CICLO de facturación
//    consumo_diario/{clienteId}_YYYY-MM-DD → acumulado del día (para gráficas)
//
//  Campos usados de config_mikrotik:
//    mikrotikIp   → IP del MikroTik (ej: "10.10.15.1")
//    mikrotikUser → usuario (ej: "admin")
//    mikrotikPass → clave
//    propietarioUid → uid del operador
// ════════════════════════════════════════════════════════════════

// ── Ciclo de facturación: inicia el día 25 ────────────────────────
// Un ciclo que arranca el 25 de un mes se etiqueta con ese mismo mes.
// Ej: 25 jun → 24 jul  = clave "2026-06"
//     25 jul → 24 ago  = clave "2026-07"
// Si el día 25 cambia en el futuro, ajusta el "25" de abajo.
// IMPORTANTE: esta clave debe coincidir EXACTAMENTE con la que usa
// InformesWidget en Flutter (_cicloDe / _mesKey) para consultar los datos.
const DIA_INICIO_CICLO = 25;

function obtenerMesKeyCiclo(fecha = new Date()) {
  let anio = fecha.getFullYear();
  let mes  = fecha.getMonth() + 1; // 1-12
  if (fecha.getDate() < DIA_INICIO_CICLO) {
    mes -= 1;
    if (mes === 0) { mes = 12; anio -= 1; }
  }
  return `${anio}-${String(mes).padStart(2, '0')}`;
}

// ── Leer todas las queues simples del MikroTik via REST API ──────
// MikroTik debe tener habilitado el servicio www-ssl (puerto 443)
// o www (puerto 80). RouterOS 6 y 7 soportan /rest
function obtenerQueuesMikroTik(host, usuario, clave) {
  return new Promise((resolve) => {
    const auth    = Buffer.from(`${usuario}:${clave}`).toString('base64');
    // Intentar primero HTTPS puerto 443, luego HTTP puerto 80.
    const options = {
      hostname:           host,
      port:               443,
      path:               '/rest/queue/simple',
      method:             'GET',
      headers:            { 'Authorization': `Basic ${auth}` },
      rejectUnauthorized: false, // MikroTik usa certificado autofirmado
    };
    const leer = (res, done) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try   { done(JSON.parse(data)); }
        catch { done([]); }
      });
    };
    let respondido = false;
    const responder = (valor) => {
      if (respondido) return;
      respondido = true;
      resolve(valor);
    };
    // 2º intento por HTTP plano (puerto 80) si HTTPS falla o se cuelga.
    let httpIntentado = false;
    const intentarHttp = () => {
      if (respondido || httpIntentado) return;
      httpIntentado = true;
      console.log(`[CONSUMO] HTTPS falló o no respondió en ${host}, intentando HTTP...`);
      const reqHttp = http.request({ ...options, port: 80 }, (res) => {
        leer(res, responder);
      });
      reqHttp.on('error', (e) => {
        console.error(`[CONSUMO] HTTP tampoco respondió en ${host}: ${e.message}`);
        responder([]); // sin respuesta: NO dejamos la promesa colgada
      });
      // Antes este timeout hacía req.destroy() sin resolver → la promesa
      // quedaba pendiente para siempre y el tracking de consumo se colgaba.
      reqHttp.setTimeout(8000, () => {
        console.error(`[CONSUMO] Timeout HTTP en ${host}`);
        reqHttp.destroy();
        responder([]);
      });
      reqHttp.end();
    };

    const req = https.request(options, (res) => {
      leer(res, responder);
    });
    req.on('error', intentarHttp);
    req.setTimeout(8000, () => {
      console.error(`[CONSUMO] Timeout HTTPS en ${host}`);
      req.destroy();
      intentarHttp();
    });
    req.end();
  });
}

// ── Parsear bytes desde MikroTik ────────────────────────────────
// MikroTik puede devolver bytes de varias formas según versión:
//   - campo "bytes": "123456/789012"  (subida/bajada juntos)
//   - campos separados: "bytes-in" y "bytes-out"
//   - o "packet-count-in" / "packet-count-out"
function parsearBytes(queue) {
  let up = 0, down = 0;
  if (queue.bytes && typeof queue.bytes === 'string' && queue.bytes.includes('/')) {
    const partes = queue.bytes.split('/');
    up   = parseInt(partes[0]) || 0;
    down = parseInt(partes[1]) || 0;
  } else {
    up   = parseInt(queue['bytes-in']  || 0);
    down = parseInt(queue['bytes-out'] || 0);
  }
  return { up, down };
}

// ── Función principal de tracking ───────────────────────────────
async function ejecutarTrackingConsumo() {
  console.log('\n[CONSUMO] ═══ INICIO TRACKING ═══');
  const ahora  = new Date();
  const mesKey = obtenerMesKeyCiclo(ahora); // ← FIX: ciclo 25→24 en vez de mes calendario
  const diaKey = ahora.toISOString().split('T')[0];

  let configsSnap;
  try {
    configsSnap = await db.collection('config_mikrotik').get();
  } catch (e) {
    console.error('[CONSUMO] Error leyendo config_mikrotik:', e.message);
    return;
  }

  for (const configDoc of configsSnap.docs) {
    const cfg  = configDoc.data();
    const uid  = configDoc.id;

    // Campos exactos que usa tu Firestore
    const host    = (cfg.mikrotikIp   || '').trim();
    const usuario = (cfg.mikrotikUser || '').trim();
    const clave   = (cfg.mikrotikPass || '').trim();

    if (!host || !usuario || !clave) {
      console.log(`[CONSUMO] uid=${uid} sin config MikroTik completa, saltando`);
      continue;
    }

    // ── Obtener queues del MikroTik ─────────────────────────────
    let queues = [];
    try {
      queues = await obtenerQueuesMikroTik(host, usuario, clave);
      if (!Array.isArray(queues)) queues = [];
      console.log(`[CONSUMO] uid=${uid} host=${host} → ${queues.length} queues leídas`);
    } catch (e) {
      console.error(`[CONSUMO] uid=${uid} error conectando a MikroTik (${host}):`, e.message);
      continue;
    }

    if (queues.length === 0) {
      console.log(`[CONSUMO] uid=${uid} sin queues en MikroTik, saltando`);
      continue;
    }

    // ── Leer clientes del operador ───────────────────────────────
    let clientesSnap;
    try {
      clientesSnap = await db.collection('clientes')
        .where('propietarioUid', '==', uid)
        .get();
    } catch (e) {
      console.error(`[CONSUMO] Error leyendo clientes uid=${uid}:`, e.message);
      continue;
    }

    // Firestore permite máx 500 operaciones por batch
    // Dividimos en lotes de 400 para tener margen
    const MAX_BATCH = 400;
    let batch        = db.batch();
    let opsEnBatch   = 0;
    let procesados   = 0;

    const commitBatch = async () => {
      if (opsEnBatch > 0) {
        await batch.commit();
        batch      = db.batch();
        opsEnBatch = 0;
      }
    };

    for (const clienteDoc of clientesSnap.docs) {
      const cliente = clienteDoc.data();
      const ip      = (cliente.ipatn || '').trim();
      if (!ip) continue;

      // ── Buscar queue del cliente por IP o nombre ───────────────
      const queue = queues.find(q => {
        const target      = (q.target || q['target-addresses'] || '').replace('/32', '').trim();
        const qNombre     = (q.name || q.comment || '').toLowerCase();
        const cNombre     = `${cliente.nombre || ''} ${cliente.apellido || ''}`.toLowerCase().trim();
        return target === ip
          || qNombre.includes(ip)
          || (cNombre.length > 3 && qNombre.includes(cNombre));
      });

      if (!queue) continue; // sin queue para este cliente

      const { up: bytesUp, down: bytesDown } = parsearBytes(queue);

      // ── Leer último snapshot para calcular delta ───────────────
      const snapId  = `${clienteDoc.id}_last`;
      const snapRef = db.collection('consumo_snapshots').doc(snapId);
      let deltaUp   = 0;
      let deltaDown = 0;
      let esPrimerSnapshot = false;

      try {
        const lastSnap = await snapRef.get();
        if (lastSnap.exists) {
          const last = lastSnap.data();
          if (bytesUp >= (last.bytesUp || 0) && bytesDown >= (last.bytesDown || 0)) {
            // Normal: acumular diferencia
            deltaUp   = bytesUp   - (last.bytesUp   || 0);
            deltaDown = bytesDown - (last.bytesDown || 0);
          } else {
            // Reinicio detectado (contador cayó)
            console.log(`[CONSUMO] ⚠️  Reinicio MikroTik detectado — ${cliente.nombre} (${ip})`);
            deltaUp   = bytesUp;
            deltaDown = bytesDown;
          }
        } else {
          // Primera vez — solo guardar snapshot, no acumular
          esPrimerSnapshot = true;
          console.log(`[CONSUMO] 📸 Primer snapshot: ${cliente.nombre} (${ip})`);
        }
      } catch (e) {
        console.error(`[CONSUMO] Error leyendo snapshot ${snapId}:`, e.message);
        continue;
      }

      // ── Guardar snapshot actual (siempre) ─────────────────────
      batch.set(snapRef, {
        bytesUp,
        bytesDown,
        ts:             admin.firestore.Timestamp.now(),
        clienteId:      clienteDoc.id,
        propietarioUid: uid,
        ip,
      });
      opsEnBatch++;

      // ── Acumular solo si hay delta y no es primer snapshot ─────
      if (!esPrimerSnapshot && (deltaUp > 0 || deltaDown > 0)) {
        // Acumulado del ciclo de facturación (25 → 24)
        const mesRef = db.collection('consumo_mensual')
          .doc(`${clienteDoc.id}_${mesKey}`);

        batch.set(mesRef, {
          clienteId:           clienteDoc.id,
          propietarioUid:      uid,
          mes:                 mesKey,
          nombre:              `${cliente.nombre || ''} ${cliente.apellido || ''}`.trim(),
          ip,
          totalUpBytes:        admin.firestore.FieldValue.increment(deltaUp),
          totalDownBytes:      admin.firestore.FieldValue.increment(deltaDown),
          ultimaActualizacion: admin.firestore.Timestamp.now(),
        }, { merge: true });
        opsEnBatch++;

        // Acumulado diario (calendario real, para gráficas día a día)
        const diaRef = db.collection('consumo_diario')
          .doc(`${clienteDoc.id}_${diaKey}`);

        batch.set(diaRef, {
          clienteId:           clienteDoc.id,
          propietarioUid:      uid,
          fecha:               diaKey,
          mes:                 mesKey,
          nombre:              `${cliente.nombre || ''} ${cliente.apellido || ''}`.trim(),
          ip,
          totalUpBytes:        admin.firestore.FieldValue.increment(deltaUp),
          totalDownBytes:      admin.firestore.FieldValue.increment(deltaDown),
          ultimaActualizacion: admin.firestore.Timestamp.now(),
        }, { merge: true });
        opsEnBatch++;

        procesados++;
        const upMB   = (deltaUp   / 1e6).toFixed(2);
        const downMB = (deltaDown / 1e6).toFixed(2);
        console.log(`[CONSUMO] ✅ ${cliente.nombre} (${ip}) ↑${upMB}MB ↓${downMB}MB`);
      }

      // Commit si estamos cerca del límite del batch
      if (opsEnBatch >= MAX_BATCH) {
        try {
          await commitBatch();
          console.log(`[CONSUMO] Batch intermedio guardado`);
        } catch (e) {
          console.error(`[CONSUMO] Error en batch intermedio:`, e.message);
        }
      }
    } // fin loop clientes

    // Commit final
    try {
      await commitBatch();
      console.log(`[CONSUMO] uid=${uid} ✅ Tracking completo — ${procesados} clientes con consumo`);
    } catch (e) {
      console.error(`[CONSUMO] Error en batch final uid=${uid}:`, e.message);
    }
  } // fin loop operadores

  console.log('[CONSUMO] ═══ FIN TRACKING ═══\n');
}

// ── Cron: cada 30 minutos ────────────────────────────────────────
cron.schedule('*/30 * * * *', async () => {
  console.log('[CRON] Ejecutando tracking de consumo...');
  try   { await ejecutarTrackingConsumo(); }
  catch (e) { console.error('[CRON] Error en tracking consumo:', e.message); }
});

// ── Endpoint manual para probar desde navegador/Postman ─────────
// GET http://5.161.88.42:3000/consumo/manual?apikey=starkgo_admin_2025
app.get('/consumo/manual', async (req, res) => {
  const { apikey } = req.query;
  if (apikey !== 'starkgo_admin_2025') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  try {
    await ejecutarTrackingConsumo();
    res.json({ ok: true, ejecutado: new Date().toISOString() });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── Endpoint para ver consumo de un cliente específico ───────────
// GET http://5.161.88.42:3000/consumo/cliente?clienteId=XXX&mes=2025-07&apikey=starkgo_admin_2025
app.get('/consumo/cliente', async (req, res) => {
  const { clienteId, mes, apikey } = req.query;
  if (apikey !== 'starkgo_admin_2025') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  if (!clienteId) return res.status(400).json({ error: 'Falta clienteId' });
  try {
    const ahora  = new Date();
    const mesKey = mes || obtenerMesKeyCiclo(ahora); // ← FIX: usa ciclo, no mes calendario
    const snap   = await db.collection('consumo_mensual').doc(`${clienteId}_${mesKey}`).get();
    if (!snap.exists) return res.json({ clienteId, mes: mesKey, sin_datos: true });
    const data = snap.data();
    const upGB   = ((data.totalUpBytes   || 0) / 1e9).toFixed(3);
    const downGB = ((data.totalDownBytes || 0) / 1e9).toFixed(3);
    res.json({ ...data, totalUpGB: upGB, totalDownGB: downGB });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── Endpoint para ver resumen de consumo de todos los clientes ───
// GET http://5.161.88.42:3000/consumo/resumen?uid=XXX&mes=2025-07&apikey=starkgo_admin_2025
app.get('/consumo/resumen', async (req, res) => {
  const { uid, mes, apikey } = req.query;
  if (apikey !== 'starkgo_admin_2025') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  if (!uid) return res.status(400).json({ error: 'Falta uid' });
  try {
    const ahora  = new Date();
    const mesKey = mes || obtenerMesKeyCiclo(ahora); // ← FIX: usa ciclo, no mes calendario
    const snap   = await db.collection('consumo_mensual')
      .where('propietarioUid', '==', uid)
      .where('mes', '==', mesKey)
      .get();
    const clientes = snap.docs.map(d => {
      const data = d.data();
      return {
        clienteId:   data.clienteId,
        nombre:      data.nombre,
        ip:          data.ip,
        upGB:        ((data.totalUpBytes   || 0) / 1e9).toFixed(3),
        downGB:      ((data.totalDownBytes || 0) / 1e9).toFixed(3),
        totalGB:     (((data.totalUpBytes || 0) + (data.totalDownBytes || 0)) / 1e9).toFixed(3),
        actualizado: data.ultimaActualizacion?.toDate?.() || null,
      };
    });
    // Ordenar de mayor a menor consumo total
    clientes.sort((a, b) => parseFloat(b.totalGB) - parseFloat(a.totalGB));
    res.json({ uid, mes: mesKey, total_clientes: clientes.length, clientes });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

console.log('[CONSUMO] Sistema de tracking de consumo cargado ✅');
console.log('[CONSUMO] Ciclo de facturación: día 25');
console.log('[CONSUMO] Cron: cada 30 minutos');
console.log('[CONSUMO] Test: GET /consumo/manual?apikey=starkgo_admin_2025');

// ════════════════════════════════════════════════════════════════
//  DIAGNÓSTICO CONSUMO — Solo lectura, no modifica nada
//
//  Compara, para cada cliente, el total guardado en consumo_mensual
//  del ciclo actual contra la suma real de consumo_diario desde el
//  día 25 hasta hoy. Si coinciden, el dato está bien. Si el de
//  consumo_mensual es mucho más grande, hay datos viejos mezclados.
//
//  USO:
//  GET http://5.161.88.42:3000/consumo/diagnostico?uid=TU_UID&apikey=starkgo_admin_2025
// ════════════════════════════════════════════════════════════════

app.get('/consumo/diagnostico', async (req, res) => {
  const { uid, apikey } = req.query;
  if (apikey !== 'starkgo_admin_2025') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  if (!uid) return res.status(400).json({ error: 'Falta uid' });

  try {
    const ahora = new Date();
    const mesKey = obtenerMesKeyCiclo(ahora);

    // Determinar fecha de inicio del ciclo actual (el día 25)
    let [anioCiclo, mesCiclo] = mesKey.split('-').map(Number);
    const fechaInicioCiclo = new Date(anioCiclo, mesCiclo - 1, DIA_INICIO_CICLO);

    // Traer todos los docs de consumo_mensual del ciclo actual para este uid
    const mensualSnap = await db.collection('consumo_mensual')
      .where('propietarioUid', '==', uid)
      .where('mes', '==', mesKey)
      .get();

    const resultados = [];

    for (const doc of mensualSnap.docs) {
      const data = doc.data();
      const clienteId = data.clienteId;
      const guardadoUp = data.totalUpBytes || 0;
      const guardadoDown = data.totalDownBytes || 0;
      const guardadoTotalGB = (guardadoUp + guardadoDown) / 1e9;

      // Sumar consumo_diario para este cliente desde el día 25 hasta hoy
      const diariosSnap = await db.collection('consumo_diario')
        .where('clienteId', '==', clienteId)
        .where('propietarioUid', '==', uid)
        .get();

      let realUp = 0, realDown = 0;
      const diasIncluidos = [];
      for (const d of diariosSnap.docs) {
        const dd = d.data();
        const fechaDoc = new Date(dd.fecha + 'T00:00:00');
        if (fechaDoc >= fechaInicioCiclo && fechaDoc <= ahora) {
          realUp += dd.totalUpBytes || 0;
          realDown += dd.totalDownBytes || 0;
          diasIncluidos.push(dd.fecha);
        }
      }
      const realTotalGB = (realUp + realDown) / 1e9;

      const diferenciaGB = guardadoTotalGB - realTotalGB;
      const sospechoso = diferenciaGB > 5; // más de 5GB de diferencia = sospechoso

      resultados.push({
        cliente: data.nombre,
        clienteId,
        guardado_en_mensual_GB: guardadoTotalGB.toFixed(2),
        real_suma_diaria_GB: realTotalGB.toFixed(2),
        diferencia_GB: diferenciaGB.toFixed(2),
        dias_diarios_encontrados: diasIncluidos.length,
        sospechoso,
      });
    }

    resultados.sort((a, b) => parseFloat(b.diferencia_GB) - parseFloat(a.diferencia_GB));

    res.json({
      uid,
      cicloActual: mesKey,
      fechaInicioCiclo: fechaInicioCiclo.toISOString().split('T')[0],
      hoy: ahora.toISOString().split('T')[0],
      total_clientes_revisados: resultados.length,
      clientes_sospechosos: resultados.filter(r => r.sospechoso).length,
      clientes: resultados,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

console.log('[DIAGNOSTICO] Endpoint de diagnóstico cargado — GET /consumo/diagnostico?uid=XXX&apikey=starkgo_admin_2025');


// ════════════════════════════════════════════════════════════════
//  BUSCAR CLIENTE POR NOMBRE — Solo lectura
//  Para encontrar el propietarioUid de una cuenta cuando no
//  aparece en /facturacion/status (porque no tiene activo:true).
//
//  USO:
//  GET http://5.161.88.42:3000/consumo/buscar-cliente?nombre=wilfader&apikey=starkgo_admin_2025
// ════════════════════════════════════════════════════════════════

app.get('/consumo/buscar-cliente', async (req, res) => {
  const { nombre, apikey } = req.query;
  if (apikey !== 'starkgo_admin_2025') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  if (!nombre) return res.status(400).json({ error: 'Falta nombre' });
  try {
    const busq = nombre.toLowerCase().trim();
    const snap = await db.collection('clientes').get();
    const encontrados = snap.docs
      .map(d => ({ id: d.id, ...d.data() }))
      .filter(c => (c.nombre || '').toLowerCase().includes(busq))
      .map(c => ({
        clienteId: c.id,
        nombre: c.nombre,
        apellido: c.apellido || '',
        ip: c.ipatn || '',
        status: c.status,
        propietarioUid: c.propietarioUid,
      }));
    res.json({ busqueda: nombre, total_encontrados: encontrados.length, clientes: encontrados });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

console.log('[BUSCAR] Endpoint de búsqueda cargado — GET /consumo/buscar-cliente?nombre=XXX&apikey=starkgo_admin_2025');


// ════════════════════════════════════════════════════════════════
//  CORREGIR CICLO — Escribe datos (una sola vez)
//
//  Recalcula consumo_mensual del ciclo actual para un uid,
//  reemplazando (no sumando) el total por la suma real de
//  consumo_diario desde el día 25 hasta hoy. Corrige la mezcla
//  de datos viejos detectada por /consumo/diagnostico.
//
//  USO (requiere confirmar=si para evitar corridas accidentales):
//  GET http://5.161.88.42:3000/consumo/corregir-ciclo?uid=XXX&apikey=starkgo_admin_2025&confirmar=si
// ════════════════════════════════════════════════════════════════

app.get('/consumo/corregir-ciclo', async (req, res) => {
  const { uid, apikey, confirmar } = req.query;
  if (apikey !== 'starkgo_admin_2025') {
    return res.status(401).json({ error: 'No autorizado' });
  }
  if (!uid) return res.status(400).json({ error: 'Falta uid' });
  if (confirmar !== 'si') {
    return res.status(400).json({ error: 'Falta confirmar=si en la URL para ejecutar la corrección' });
  }

  try {
    const ahora = new Date();
    const mesKey = obtenerMesKeyCiclo(ahora);
    let [anioCiclo, mesCiclo] = mesKey.split('-').map(Number);
    const fechaInicioCiclo = new Date(anioCiclo, mesCiclo - 1, DIA_INICIO_CICLO);

    const mensualSnap = await db.collection('consumo_mensual')
      .where('propietarioUid', '==', uid)
      .where('mes', '==', mesKey)
      .get();

    const corregidos = [];
    let batch = db.batch();
    let opsEnBatch = 0;

    for (const doc of mensualSnap.docs) {
      const data = doc.data();
      const clienteId = data.clienteId;
      const guardadoTotalGB = ((data.totalUpBytes || 0) + (data.totalDownBytes || 0)) / 1e9;

      const diariosSnap = await db.collection('consumo_diario')
        .where('clienteId', '==', clienteId)
        .where('propietarioUid', '==', uid)
        .get();

      let realUp = 0, realDown = 0;
      for (const d of diariosSnap.docs) {
        const dd = d.data();
        const fechaDoc = new Date(dd.fecha + 'T00:00:00');
        if (fechaDoc >= fechaInicioCiclo && fechaDoc <= ahora) {
          realUp += dd.totalUpBytes || 0;
          realDown += dd.totalDownBytes || 0;
        }
      }
      const realTotalGB = (realUp + realDown) / 1e9;

      batch.set(doc.ref, {
        totalUpBytes: realUp,
        totalDownBytes: realDown,
        ultimaActualizacion: admin.firestore.Timestamp.now(),
        corregidoDesdeGB: guardadoTotalGB.toFixed(2),
      }, { merge: true });
      opsEnBatch++;

      corregidos.push({
        cliente: data.nombre,
        clienteId,
        antes_GB: guardadoTotalGB.toFixed(2),
        despues_GB: realTotalGB.toFixed(2),
      });

      if (opsEnBatch >= 400) {
        await batch.commit();
        batch = db.batch();
        opsEnBatch = 0;
      }
    }

    if (opsEnBatch > 0) await batch.commit();

    res.json({
      uid,
      cicloActual: mesKey,
      total_corregidos: corregidos.length,
      clientes: corregidos,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

console.log('[CORREGIR] Endpoint de corrección cargado — GET /consumo/corregir-ciclo?uid=XXX&apikey=starkgo_admin_2025&confirmar=si');

app.listen(3000, () => console.log('StarkGo API puerto 3000 v2.5 - lista'));

// ════════════════════════════════════════════════════════════════
//  MIKROFICHAS — Perfiles (Planes), Fichas y Dashboard
// ════════════════════════════════════════════════════════════════

function mikrotikRest(host, usuario, clave, path, method, body) {
  return new Promise((resolve, reject) => {
    const auth = Buffer.from(`${usuario}:${clave}`).toString('base64');
    const payload = body ? JSON.stringify(body) : null;
    const req = https.request({
      hostname: host, port: 443, path, method,
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
      },
      rejectUnauthorized: false,
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data || '{}') }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function obtenerConfigDesdeApikey(apikey) {
  const snap = await db.collection('config_mikrotik').where('vpsApiKey', '==', apikey).limit(1).get();
  if (snap.empty) return null;
  return { id: snap.docs[0].id, ...snap.docs[0].data() };
}

function segundosDesdeDuracion(dias, horas, minutos, segundos) {
  return (Number(dias)||0)*86400 + (Number(horas)||0)*3600 + (Number(minutos)||0)*60 + (Number(segundos)||0);
}

// Convierte segundos a formato de tiempo de RouterOS ("1h", "1d2h3m4s").
function segundosATimeRos(totalSegundos) {
  const t = Math.max(0, Math.floor(Number(totalSegundos) || 0));
  const d = Math.floor(t / 86400);
  const h = Math.floor((t % 86400) / 3600);
  const m = Math.floor((t % 3600) / 60);
  const s = t % 60;
  const partes = [];
  if (d) partes.push(`${d}d`);
  if (h) partes.push(`${h}h`);
  if (m) partes.push(`${m}m`);
  if (s) partes.push(`${s}s`);
  return partes.length ? partes.join('') : '0s';
}

// Normaliza cualquier duración ("3600", "1h", "01:00:00") a formato RouterOS.
function normalizarTiempoRos(valor) {
  if (valor === null || valor === undefined) return null;
  const v = String(valor).trim();
  if (v === '') return null;
  if (/^\d+$/.test(v)) return segundosATimeRos(parseInt(v, 10));
  return v;
}

function generarCodigoFicha(longitud = 6) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // sin 0/O/1/I
  let code = '';
  for (let i = 0; i < longitud; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return code;
}

function crearHotspotUserMikroTik(host, usuario, clave, login, pass, perfil, limitUptime) {
  const body = { name: login, password: pass, profile: perfil };
  // 'limit-uptime' es el TIEMPO TOTAL acumulado permitido para la ficha.
  // Sin esto, la ficha nunca "se acaba" (el session-timeout del perfil solo
  // limita cada sesión y se reinicia al volver a entrar).
  if (limitUptime && limitUptime !== '0s') body['limit-uptime'] = limitUptime;
  return mikrotikRest(host, usuario, clave, '/rest/ip/hotspot/user', 'PUT', body);
}

// ════════════════════════════════════════════════════════════════
//  DHCP LEASES — ver y marcar las IPs que el MikroTik le da a las antenas
//
//  Flujo real del operador: conecta la antena → el MikroTik le asigna una IP →
//  necesita ESA IP para registrar el cliente (campo `ipatn`). Antes había que
//  entrar a WinBox a verla.
//
//  "Marcar" deja el lease:
//    · ESTÁTICO (la antena conserva la IP, el DHCP no se la cambia),
//    · con comentario `StarkGo <cliente>`,
//    · y la IP en la address-list `starkgo` (para reglas propias).
//  Se intenta por REST (instantáneo); si el REST no está disponible, el VPS
//  encola la acción `marcarLease` y el router lo aplica en el próximo ciclo.
// ════════════════════════════════════════════════════════════════

// GET /mikrotik/leases?apikey=… → leases del DHCP del router
app.get('/mikrotik/leases', async (req, res) => {
  const { apikey } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
    const r = await mikrotikRest(
      cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass,
      '/rest/ip/dhcp-server/lease', 'GET'
    );
    if (r.status >= 400) {
      return res.status(502).json({
        error: `El MikroTik respondió ${r.status}`,
        detalle: typeof r.body === 'string' ? r.body.slice(0, 200) : r.body,
        pista:
          'Revisá que el servicio www-ssl (o www) esté habilitado y que el VPS ' +
          'llegue al router (es el mismo que usa el tracking de consumo).',
      });
    }
    const leases = (Array.isArray(r.body) ? r.body : []).map((l) => ({
      id: l['.id'] || null,
      ip: l.address || '',
      mac: l['mac-address'] || '',
      nombre: l['host-name'] || '',
      comentario: l.comment || '',
      dinamica: l.dynamic === true || l.dynamic === 'true',
      estado: l.status || '',
      servidor: l.server || '',
      caduca: l['expires-after'] || '',
      visto: l['last-seen'] || '',
    }));
    res.json({ ok: true, fuente: 'vps (rest)', total: leases.length, leases });
  } catch (e) {
    console.error('[LEASES] Error leyendo leases:', e.message);
    res.status(502).json({ error: `No pude leer los leases: ${e.message}` });
  }
});

// POST /mikrotik/lease/marcar  { apikey, ip, nombre }
// Deja el lease ESTÁTICO + comentado + en la address-list `starkgo`.
// (Lo llama el botón "Marcar StarkGo" y también el alta de cliente, solo.)
app.post('/mikrotik/lease/marcar', async (req, res) => {
  const { apikey, ip, nombre } = req.body || {};
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  const ipOk = _rosIp(ip);
  if (!ipOk) return res.status(400).json({ error: 'Falta la IP (o no es válida)' });
  const quien = _ros(nombre, 40) || 'cliente';

  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });

    // (1) ¿Existe un lease (DHCP) para esa IP?
    const busca = await mikrotikRest(
      cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass,
      `/rest/ip/dhcp-server/lease?address=${encodeURIComponent(ipOk)}`, 'GET'
    );
    const lease = Array.isArray(busca.body) && busca.body[0] ? busca.body[0] : null;
    if (!lease) {
      // IP fija (fuera del DHCP): igual queda marcada en la address-list.
      encolar(apikey, { accion: 'marcarLease', ip: ipOk, nombre: quien });
      return res.json({
        ok: true,
        via: 'cola',
        ip: ipOk,
        motivo: 'Esa IP no está en los leases del DHCP: la marqué en la lista `starkgo`.',
      });
    }

    const id = String(lease['.id'] || '');
    const eraDinamica = lease.dynamic === true || lease.dynamic === 'true';

    // (2) Si es dinámica → ESTÁTICA (así la antena conserva esa IP).
    let estaticaOk = !eraDinamica;
    if (eraDinamica && id) {
      const mk = await mikrotikRest(
        cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass,
        '/rest/ip/dhcp-server/lease/make-static', 'POST', { '.id': id }
      );
      estaticaOk = mk.status < 400;
      if (!estaticaOk) {
        console.warn('[LEASES] make-static:', mk.status, JSON.stringify(mk.body).slice(0, 150));
      }
    }

    // (3) Comentario identificable (sólo editable si ya quedó estática).
    const comentario = `StarkGo ${quien}`;
    let comentarioOk = false;
    if (estaticaOk && id) {
      const patch = await mikrotikRest(
        cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass,
        `/rest/ip/dhcp-server/lease/${id}`, 'PATCH', { comment: comentario }
      );
      comentarioOk = patch.status < 400;
    }

    // (4) Address-list `starkgo` (para las reglas propias del operador).
    let listaOk = false;
    try {
      const ya = await mikrotikRest(
        cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass,
        `/rest/ip/firewall/address-list?list=starkgo&address=${encodeURIComponent(ipOk)}`, 'GET'
      );
      if (Array.isArray(ya.body) && ya.body.length > 0) {
        listaOk = true;
      } else {
        const add = await mikrotikRest(
          cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass,
          '/rest/ip/firewall/address-list', 'PUT',
          { list: 'starkgo', address: ipOk, comment: comentario }
        );
        listaOk = add.status < 400;
      }
    } catch (e) {
      console.warn('[LEASES] address-list:', e.message);
    }

    // Si el REST no pudo dejarlo estático/comentado, encolamos el script.
    const encolado = !estaticaOk || !comentarioOk;
    if (encolado) encolar(apikey, { accion: 'marcarLease', ip: ipOk, nombre: quien });

    console.log(
      `[LEASES] Marcar ${ipOk} (${quien}) → estatica=${estaticaOk} ` +
        `comentario=${comentarioOk} lista=${listaOk} encolado=${encolado}`
    );
    res.json({
      ok: estaticaOk || comentarioOk || listaOk,
      via: 'rest',
      ip: ipOk,
      eraDinamica,
      estatica: estaticaOk,
      comentario: comentarioOk ? comentario : null,
      addressList: listaOk,
      encolado,
    });
  } catch (e) {
    console.error('[LEASES] marcar:', e.message);
    // Último recurso: la cola (el router lo aplica en el próximo ciclo).
    encolar(apikey, { accion: 'marcarLease', ip: ipOk, nombre: quien });
    res.json({ ok: true, via: 'cola', error: e.message });
  }
});

// ── PERFILES (Planes) ──────────────────────────────────────────

app.get('/hotspot/perfiles', async (req, res) => {
  const { apikey } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
    const r = await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, '/rest/ip/hotspot/user/profile', 'GET');
    const perfiles = Array.isArray(r.body) ? r.body : [];

    const preciosSnap = await db.collection('planes_precio').where('propietarioUid', '==', cfg.propietarioUid).get();
    const mapaPrecios = {};
    preciosSnap.docs.forEach(d => { mapaPrecios[d.data().nombrePerfil] = d.data().precio; });

    res.json({
      perfiles: perfiles
        .filter(p => p.name !== 'default')
        .map(p => ({
          id: p['.id'],
          nombre: p.name,
          rateLimit: p['rate-limit'] || '',
          sessionTimeout: p['session-timeout'] || '0s',
          sharedUsers: p['shared-users'] || '1',
          precio: mapaPrecios[p.name] || 0,
        })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/hotspot/perfiles', async (req, res) => {
  const { apikey, nombre, precio, usuariosCompartidos, velUpl, velDow, dias, horas, minutos, segundos } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  if (!nombre || /\s/.test(nombre)) return res.status(400).json({ error: 'Nombre sin espacios requerido' });
  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
    const sessionTimeout = segundosDesdeDuracion(dias, horas, minutos, segundos);
    const body = {
      name: nombre,
      'rate-limit': `${velUpl}/${velDow}`,
      'shared-users': String(usuariosCompartidos || 1),
      'session-timeout': normalizarTiempoRos(sessionTimeout) || '0s',
    };
    const existente = await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, `/rest/ip/hotspot/user/profile?name=${nombre}`, 'GET');
    if (Array.isArray(existente.body) && existente.body.length > 0) {
      await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, `/rest/ip/hotspot/user/profile/${existente.body[0]['.id']}`, 'PATCH', body);
    } else {
      await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, `/rest/ip/hotspot/user/profile`, 'PUT', body);
    }
    await db.collection('planes_precio').doc(`${cfg.propietarioUid}_${nombre}`).set({
      nombrePerfil: nombre, precio: precio || 0, propietarioUid: cfg.propietarioUid,
      actualizado: admin.firestore.Timestamp.now(),
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/hotspot/perfiles/:nombre', async (req, res) => {
  const { apikey } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
    const nombre = req.params.nombre;
    const existente = await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, `/rest/ip/hotspot/user/profile?name=${nombre}`, 'GET');
    if (Array.isArray(existente.body) && existente.body.length > 0) {
      await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, `/rest/ip/hotspot/user/profile/${existente.body[0]['.id']}`, 'DELETE');
    }
    await db.collection('planes_precio').doc(`${cfg.propietarioUid}_${nombre}`).delete();
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── FICHAS_VAUCHES ────────────────────────────────────────────

app.post('/hotspot/generar-fichas', async (req, res) => {
  const { apikey, perfil, cantidad, precio } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  if (!perfil || !cantidad) return res.status(400).json({ error: 'Faltan datos' });
  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });

    // ── Copiar la duración del perfil como 'limit-uptime' de cada ficha ──
    // Esto es lo que hace que la ficha se ACABE (tiempo total acumulado).
    let limitUptime = null;
    try {
      const pr = await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass,
        `/rest/ip/hotspot/user/profile?name=${encodeURIComponent(perfil)}`, 'GET');
      const prof = Array.isArray(pr.body) && pr.body[0] ? pr.body[0] : null;
      if (prof) limitUptime = normalizarTiempoRos(prof['session-timeout']);
      console.log(`[FICHAS] perfil=${perfil} session-timeout=${prof ? prof['session-timeout'] : 'NO ENCONTRADO'} -> limit-uptime=${limitUptime}`);
    } catch (e) {
      console.error('[FICHAS] No se pudo leer el perfil:', e.message);
    }

    const fichas = [];
    const batch = db.batch();
    for (let i = 0; i < cantidad; i++) {
      const codigo = generarCodigoFicha();
      await crearHotspotUserMikroTik(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, codigo, codigo, perfil, limitUptime);
      const ref = db.collection('fichas_vauches').doc();
      batch.set(ref, {
        codigo, perfil, precio: precio || 0,
        propietarioUid: cfg.propietarioUid,
        estado: 'sin_usar',
        generadaPdf: false,
        fechaCreacion: admin.firestore.Timestamp.now(),
      });
      fichas.push({ codigo, perfil });
    }
    await batch.commit();
    res.json({ ok: true, fichas });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/fichas/marcar-pdf', async (req, res) => {
  const { apikey, codigos } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
    const batch = db.batch();
    for (const codigo of (codigos || [])) {
      const snap = await db.collection('fichas_vauches')
        .where('codigo', '==', codigo).where('propietarioUid', '==', cfg.propietarioUid).limit(1).get();
      if (!snap.empty) batch.update(snap.docs[0].ref, { generadaPdf: true });
    }
    await batch.commit();
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/fichas/listar', async (req, res) => {
  const { apikey, perfil, estado } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  const cfg = await obtenerConfigDesdeApikey(apikey);
  if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
  let q = db.collection('fichas_vauches').where('propietarioUid', '==', cfg.propietarioUid);
  if (perfil) q = q.where('perfil', '==', perfil);
  if (estado) q = q.where('estado', '==', estado);
  const snap = await q.get();
  res.json({ fichas: snap.docs.map(d => ({ id: d.id, ...d.data() })) });
});

app.delete('/fichas/:codigo', async (req, res) => {
  const { apikey } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
    const codigo = req.params.codigo;
    const buscar = await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, `/rest/ip/hotspot/user?name=${codigo}`, 'GET');
    if (Array.isArray(buscar.body) && buscar.body.length > 0) {
      await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, `/rest/ip/hotspot/user/${buscar.body[0]['.id']}`, 'DELETE');
    }
    const fichaSnap = await db.collection('fichas_vauches').where('codigo', '==', codigo).limit(1).get();
    if (!fichaSnap.empty) await fichaSnap.docs[0].ref.delete();
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/fichas/sincronizar-estado', async (req, res) => {
  const { apikey } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
    const usuarios = await mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, '/rest/ip/hotspot/user', 'GET');
    const mapaUso = {};
    for (const u of (usuarios.body || [])) {
      mapaUso[u.name] = (u.uptime && u.uptime !== '0s');
    }
    const fichasSnap = await db.collection('fichas_vauches')
      .where('propietarioUid', '==', cfg.propietarioUid).where('estado', '==', 'sin_usar').get();
    const batch = db.batch();
    let actualizadas = 0;
    fichasSnap.docs.forEach(d => {
      if (mapaUso[d.data().codigo]) {
        batch.update(d.ref, { estado: 'usada', fechaUso: admin.firestore.Timestamp.now() });
        actualizadas++;
      }
    });
    await batch.commit();
    res.json({ ok: true, actualizadas });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── DASHBOARD ───────────────────────────────────────────────

// POST /dashboard/reportar → lo llama el script "starkgo-dashboard-report"
// que la app genera para el MikroTik (cada 10 min). Guarda el snapshot del
// hotspot en Firestore para que el dashboard funcione incluso si el VPS no
// puede entrar al router por REST. (Antes este endpoint NO existía → el
// script del router hacía POST a un 404 y el reporte se perdía.)
app.post('/dashboard/reportar', async (req, res) => {
  const body = req.body || {};
  const valida = await validarApikey(body.apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const cfg = await obtenerConfigDesdeApikey(body.apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
    const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);
    await db.collection('hotspot_snapshots').doc(cfg.propietarioUid).set(
      {
        propietarioUid: cfg.propietarioUid,
        reportadoEn: admin.firestore.Timestamp.now(),
        perfiles: Array.isArray(body.perfiles) ? body.perfiles.slice(0, 200) : [],
        usuarios: Array.isArray(body.usuarios) ? body.usuarios.slice(0, 500) : [],
        activos: num(body.activos),
        ipBindings: num(body.ipBindings),
        servers: num(body.servers),
      },
      { merge: true }
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/dashboard/resumen', async (req, res) => {
  const { apikey } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const cfg = await obtenerConfigDesdeApikey(apikey);
    if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });

    const fichasSnap = await db.collection('fichas_vauches').where('propietarioUid', '==', cfg.propietarioUid).get();
    const fichas = fichasSnap.docs.map(d => d.data());
    const fichasPdf = fichas.filter(f => f.generadaPdf === true);

    // 1) Datos en vivo por REST (requiere www/www-ssl habilitado en el router).
    try {
      const [servers, perfiles, usuarios, activos, ipBindings] = await Promise.all([
        mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, '/rest/ip/hotspot', 'GET'),
        mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, '/rest/ip/hotspot/user/profile', 'GET'),
        mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, '/rest/ip/hotspot/user', 'GET'),
        mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, '/rest/ip/hotspot/active', 'GET'),
        mikrotikRest(cfg.mikrotikIp, cfg.mikrotikUser, cfg.mikrotikPass, '/rest/ip/hotspot/ip-binding', 'GET'),
      ]);
      return res.json({
        fuente: 'router',
        servidoresHotspot: Array.isArray(servers.body) ? servers.body.length : 0,
        planes:            Array.isArray(perfiles.body) ? perfiles.body.filter(p => p.name !== 'default').length : 0,
        usuarios:          Array.isArray(usuarios.body) ? usuarios.body.length : 0,
        activos:           Array.isArray(activos.body) ? activos.body.length : 0,
        ipBindings:        Array.isArray(ipBindings.body) ? ipBindings.body.length : 0,
        fichas:            fichas.length,
        fichasPdf:         fichasPdf.length,
      });
    } catch (eRest) {
      console.warn(`[DASHBOARD] REST al router falló (${eRest.message}); uso el snapshot del script.`);
    }

    // 2) Fallback: último reporte que subió el propio MikroTik.
    const snap = await db.collection('hotspot_snapshots').doc(cfg.propietarioUid).get();
    if (snap.exists) {
      const d = snap.data() || {};
      const reportadoEn = d.reportadoEn && d.reportadoEn.toDate ? d.reportadoEn.toDate().toISOString() : null;
      return res.json({
        fuente: 'snapshot',
        reportadoEn,
        servidoresHotspot: Number(d.servers || 0),
        planes:            Array.isArray(d.perfiles) ? d.perfiles.filter(p => p && p.name !== 'default').length : 0,
        usuarios:          Array.isArray(d.usuarios) ? d.usuarios.length : 0,
        activos:           Number(d.activos || 0),
        ipBindings:        Number(d.ipBindings || 0),
        fichas:            fichas.length,
        fichasPdf:         fichasPdf.length,
      });
    }

    return res.status(502).json({
      error:
        'No pude leer el hotspot del MikroTik (habilitá www/www-ssl y revisá IP/usuario/clave) ' +
        'y todavía no hay ningún reporte del script del router.',
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

console.log('[MIKROFICHAS] Endpoints de perfiles, fichas y dashboard cargados ✅');

// ════════════════════════════════════════════════════════════════
//  WIREGUARD DINÁMICO — peers del VPS (hub WireGuard)
//
//  · Estado: colección Firestore `wg_peers` (doc id = PublicKey pasado a
//    base64url: '+'→'-' y '/'→'_', porque Firestore NO admite '/' en el id).
//    La clave original queda en el campo `publicKey` del documento.
//  · IPs: pool 10.50.50.2..250 asignadas automáticamente por usuario.
//  · Config local en el VPS:
//      /etc/wireguard/wg0.interface.conf  → bloque [Interface]
//      /etc/wireguard/wg0.static.conf     → peers fijos (MikroTik, PC)
//      /etc/wireguard/wg0.conf            → regenerado = interface + estáticos + dinámicos
//  · Aplicación en vivo (sin caer la interfaz): `wg syncconf`.
//
//  Setup único (una vez en el VPS):
//    POST /wg/init con un apikey válido → separa wg0.conf en interface + estáticos
//
//  NO se usan subcarpetas por cliente: cada usuario/empresa es un peer
//  con su propia IP del pool, gestionado desde Firestore.
// ════════════════════════════════════════════════════════════════

const WG_IFACE = process.env.WG_IFACE || 'wg0';
const WG_DIR = '/etc/wireguard';
const WG_INTERFACE_FILE = `${WG_DIR}/${WG_IFACE}.interface.conf`;
const WG_STATIC_FILE = `${WG_DIR}/${WG_IFACE}.static.conf`;
const WG_CONF = `${WG_DIR}/${WG_IFACE}.conf`;
const WG_POOL = process.env.WG_POOL || '10.50.50';
const WG_POOL_INICIO = 2;
const WG_POOL_FIN = 250;

function wgSh(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', timeout: 15000 }).trim();
  } catch (e) {
    console.error('[WG] Comando falló:', cmd, '→', e.message);
    return '';
  }
}

function wgLeer(p) {
  try { return fs.readFileSync(p, 'utf8'); } catch (_) { return ''; }
}

function wgEscribir(p, contenido) {
  fs.writeFileSync(p, contenido);
}

function wgClaveValida(pk) {
  return /^[A-Za-z0-9+/]{43}=$/.test(pk);
}

// ══════════════════════════════════════════════════════════════════════════
//  ID SEGURO DE LOS PEERS EN FIRESTORE  (fix del HTTP 500 al registrar)
//
//  Una PublicKey de WireGuard es base64: puede contener '+' y '/'. Firestore
//  NO admite '/' en el id de un documento y tira:
//    "Value for argument \"documentPath\" must point to a document, but was
//     \".../...\". Your path does not contain an even number of components."
//  → el alta del peer fallaba con HTTP 500.
//
//  Solución: el doc se guarda con un id "seguro" (base64url: '+' → '-',
//  '/' → '_') y la PublicKey original queda en el campo `publicKey`, que es
//  la que se usa para `wg set` y para reconstruir wg0.conf.
// ══════════════════════════════════════════════════════════════════════════
function wgDocId(publicKey) {
  return String(publicKey || '').replace(/\+/g, '-').replace(/\//g, '_');
}

// Vuelve del id seguro a la PublicKey original. Los docs viejos (claves sin
// '+' ni '/') no se ven afectados porque su id ya era la clave cruda.
function wgDocIdAPublicKey(id) {
  return String(id || '').replace(/-/g, '+').replace(/_/g, '/');
}

// PublicKey real del peer: el campo `publicKey` o, si el doc es viejo,
// reconstruida desde su id.
function wgPublicKeyDeDoc(d) {
  const p = d.data() || {};
  return String(p.publicKey || wgDocIdAPublicKey(d.id));
}

// Busca en `wg_peers` por PublicKey aceptando el id seguro (nuevo) y el id
// crudo (docs viejos). Devuelve { ref, snap } o null.
async function wgPeerPorPublicKey(publicKey) {
  const pk = String(publicKey || '');
  const ref = db.collection('wg_peers').doc(wgDocId(pk));
  const snap = await ref.get();
  if (snap.exists) return { ref, snap };
  // Doc viejo (id = PublicKey cruda, sin '/' porque Firestore no lo permite).
  if (wgDocId(pk) !== pk && !pk.includes('/')) {
    try {
      const refViejo = db.collection('wg_peers').doc(pk);
      const snapViejo = await refViejo.get();
      if (snapViejo.exists) return { ref: refViejo, snap: snapViejo };
    } catch (e) {
      console.error('[WG] Error buscando peer viejo:', e.message);
    }
  }
  return null;
}

// Busca la próxima IP libre del pool considerando Firestore + wg0.conf actual.
async function wgIpSiguienteLibre() {
  const usadas = new Set();
  const snap = await db.collection('wg_peers').get();
  snap.docs.forEach(d => {
    const ip = String(d.data().ip || '').trim();
    if (ip.startsWith(`${WG_POOL}.`)) usadas.add(ip);
  });
  // IPs de túnel reservadas para MikroTik (generadas desde la app en
  // config_mikrotik.mikrotikTunelIp). Se excluyen para nunca chocar.
  try {
    const cfg = await db.collection('config_mikrotik').get();
    cfg.docs.forEach(d => {
      const ip = String(d.data().mikrotikTunelIp || '').trim();
      if (ip.startsWith(`${WG_POOL}.`)) usadas.add(ip);
    });
  } catch (e) {
    console.error('[WG] Error leyendo config_mikrotik para IPs del túnel:', e.message);
  }
  const conf = wgLeer(WG_CONF);
  for (const m of conf.matchAll(/AllowedIPs\s*=\s*([^\s,]+)/g)) {
    const ip = m[1].split('/')[0].trim();
    if (ip.startsWith(`${WG_POOL}.`)) usadas.add(ip);
  }
  for (let i = WG_POOL_INICIO; i <= WG_POOL_FIN; i++) {
    const ip = `${WG_POOL}.${i}`;
    if (!usadas.has(ip)) return ip;
  }
  return null;
}

// ¿La IP del túnel `ip` ya está tomada por OTRO peer u Otra empresa?
// Mira las 3 fuentes de verdad: peers dinámicos (wg_peers), las IPs reservadas
// por los MikroTik (config_mikrotik.mikrotikTunelIp) y el wg0.conf real.
// Excluye la propia PublicKey y el propio uid (para poder re-registrar).
async function wgIpTunelEnUso(ip, uid, publicKey) {
  try {
    const peers = await db.collection('wg_peers').get();
    for (const d of peers.docs) {
      if (wgPublicKeyDeDoc(d) === publicKey) continue;
      if (String(d.data().ip || '').trim() === ip) return true;
    }
    const cfg = await db.collection('config_mikrotik').get();
    for (const d of cfg.docs) {
      if (d.id === uid) continue;
      if (String(d.data().mikrotikTunelIp || '').trim() === ip) return true;
    }
    const conf = wgLeer(WG_CONF);
    // Cada bloque [Peer] tiene su PublicKey y su AllowedIPs.
    const bloques = conf.split('[Peer]');
    for (let i = 1; i < bloques.length; i++) {
      const b = bloques[i];
      const pk = (b.match(/PublicKey\s*=\s*(\S+)/) || [])[1] || '';
      if (pk === publicKey) continue;
      const aips = (b.match(/AllowedIPs\s*=\s*(.+)/) || [])[1] || '';
      const ocupada = aips
        .split(/[,\s]+/)
        .some((a) => a.trim() === `${ip}/32`);
      if (ocupada) return true;
    }
  } catch (e) {
    console.error('[WG] Error verificando si la IP del túnel está en uso:', e.message);
  }
  return false;
}
// Sin esto, regenerar wg0.conf pisaría los peers manuales (MikroTik, PC, etc).
function wgGarantizarInit() {
  if (fs.existsSync(WG_INTERFACE_FILE) && fs.existsSync(WG_STATIC_FILE)) return;
  // Si solo existe uno (init manual a medias) NO pisar: avisá y dejá que el
  // usuario corra POST /wg/init para hacer el split completo.
  if (fs.existsSync(WG_INTERFACE_FILE) || fs.existsSync(WG_STATIC_FILE)) {
    console.warn('[WG] Init incompleto en /etc/wireguard: ejecutá POST /wg/init para separar wg0.conf.');
    return;
  }
  const conf = wgLeer(WG_CONF);
  if (!conf.includes('[Interface]')) return;
  const idx = conf.indexOf('[Peer]');
  let interfaz = (idx < 0 ? conf : conf.slice(0, idx)).trimEnd();
  const estaticos = (idx < 0 ? '' : conf.slice(idx)).trim();
  // Quita comentarios finales del bloque de interfaz (p. ej. "# PEER 1: ...").
  const lineas = interfaz.split('\n');
  while (lineas.length && lineas[lineas.length - 1].trim().startsWith('#')) {
    lineas.pop();
  }
  interfaz = lineas.join('\n').trim();
  wgEscribir(WG_INTERFACE_FILE, interfaz + '\n');
  wgEscribir(WG_STATIC_FILE, estaticos + '\n');
  console.log('[WG] wg0.conf separado en interface + estáticos (auto-init)');
}

// Aplica un peer en vivo (sin reiniciar la interfaz). Si wg0 está caída,
// se ignora: al levantarse con wg-quick lee wg0.conf (ya regenerado).
function wgAplicarPeer(pub, ip) {
  wgSh(`wg set ${WG_IFACE} peer ${pub} allowed-ips ${ip}/32`);
}

// ── Helpers para peers ESTÁTICOS (MikroTik) en wg0.static.conf ──────────────
// Quita el bloque [Peer] cuya PublicKey coincide (idempotente).
function wgEliminarEstatico(pub) {
  const contenido = wgLeer(WG_STATIC_FILE);
  if (!contenido || !contenido.includes(`PublicKey = ${pub}`)) return contenido;
  const bloques = contenido.split(/(?=\[Peer\])/);
  const restantes = bloques.filter((b) => !b.includes(`PublicKey = ${pub}`));
  return restantes.join('').replace(/\n{3,}/g, '\n\n').trim() + '\n';
}

// Agrega o actualiza el bloque [Peer] del MikroTik en el archivo estático.
function wgUpsertEstatico(pub, ip, subred, nombre) {
  wgGarantizarInit();
  const base = wgEliminarEstatico(pub).replace(/\s+$/, '');
  const bloque =
    `# ${nombre || 'MikroTik'}\n` +
    `[Peer]\n` +
    `PublicKey = ${pub}\n` +
    `AllowedIPs = ${ip}/32, ${subred}\n` +
    `PersistentKeepalive = 25`;
  const finalContenido = (base ? base + '\n\n' : '') + bloque + '\n';
  wgEscribir(WG_STATIC_FILE, finalContenido);
}


// Regenera wg0.conf = interface + estáticos + peers de Firestore (persistencia).
async function wgRegenerarConf() {
  wgGarantizarInit(); // seguridad: nunca perder los peers manuales
  const interfaz = wgLeer(WG_INTERFACE_FILE).trim();
  const estaticos = wgLeer(WG_STATIC_FILE).trim();
  const dinSnap = await db.collection('wg_peers').get();
  const partes = [interfaz];
  if (estaticos) partes.push(estaticos);
  for (const d of dinSnap.docs) {
    const p = d.data();
    partes.push('');
    partes.push(`# ${p.nombre} (${p.propietarioUid})`);
    partes.push('[Peer]');
    partes.push(`PublicKey = ${wgPublicKeyDeDoc(d)}`);
    partes.push(`AllowedIPs = ${p.ip}/32`);
  }
  wgEscribir(WG_CONF, partes.join('\n').trimEnd() + '\n');
}

// Garantiza que el VPS pueda enrutar hacia la subred de antenas de la empresa:
//  · ip_forward = 1 (reenvío de paquetes del túnel)
//  · ruta 10.10.x.0/24 → dev wg0 (con Table=off wg-quick NO agrega rutas solas)
function wgGarantizarRutas(subred) {
  wgSh('sysctl -w net.ipv4.ip_forward=1');
  if (subred) wgSh(`ip route replace ${subred} dev ${WG_IFACE}`);
}

// Normaliza y valida una subred declarada por el usuario ("192.168.10.0/24").
// Devuelve la dirección de red normalizada o null si es inválida.
function wgSubredValida(s) {
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,2})$/.exec(
    String(s || '').trim()
  );
  if (!m) return null;
  const oct = [m[1], m[2], m[3], m[4]].map(Number);
  if (oct.some((o) => o > 255)) return null;
  const pref = Number(m[5]);
  if (pref < 16 || pref > 30) return null; // /24 típico; se acepta 16..30
  const mask = pref === 0 ? 0 : (0xffffffff << (32 - pref)) >>> 0;
  const ip = (((oct[0] << 24) >>> 0) + (oct[1] << 16) + (oct[2] << 8) + oct[3]) >>> 0;
  const net = (ip & mask) >>> 0;
  return (
    `${(net >>> 24) & 255}.${(net >>> 16) & 255}.${(net >>> 8) & 255}.${net & 255}` +
    `/${pref}`
  );
}

// Asigna (o devuelve) la subred de gestión/antenas del usuario.
//
//  · Si el usuario DECLARÓ su red local (config_mikrotik.subredLocal, ej.
//    "192.168.10.0/24") esa se usa como subred de antenas — así las antenas,
//    la puerta de enlace y el MikroTik coinciden con su red real. Se valida
//    que NINGUNA otra empresa la esté usando (si está tomada → error claro).
//  · Si no declaró nada, el VPS asigna una 10.10.X.0/24 libre (15..254).
//
// Devuelve { red } o { error } (nunca null a secas, para poder explicar).
async function wgAsignarSubred(uid, subredPedida) {
  const ref = db.collection('vpn_config').doc(uid);
  const existente = await ref.get();
  const actual = existente.exists ? existente.data().redAntenas || null : null;
  const deseada = wgSubredValida(subredPedida);

  // ── 1) Subred declarada por el usuario (su red local) ──
  if (deseada) {
    if (actual === deseada) {
      wgGarantizarRutas(deseada);
      return { red: deseada, declarada: true };
    }
    const snap = await db.collection('vpn_config').get();
    const ocupadaPorOtro = snap.docs.some(
      (d) => d.id !== uid && d.data().redAntenas === deseada
    );
    if (ocupadaPorOtro) {
      return {
        error:
          `La subred ${deseada} ya está en uso por otra empresa. ` +
          'Elegí otra (por ej. 192.168.20.0/24) o dejá el campo vacío para ' +
          'que el VPS te asigne una 10.10.X.0/24 libre.',
      };
    }
    // Si cambió de subred, liberamos la ruta anterior (si nadie más la usa).
    if (actual && actual !== deseada) {
      const enUso = snap.docs.some(
        (d) => d.id !== uid && d.data().redAntenas === actual
      );
      if (!enUso) wgSh(`ip route del ${actual} dev ${WG_IFACE}`);
    }
    await ref.set({ redAntenas: deseada }, { merge: true });
    wgGarantizarRutas(deseada);
    console.log(`[WG] Subred declarada por el usuario uid=${uid} → ${deseada}`);
    return { red: deseada, declarada: true };
  }

  // ── 2) Ya tenía una asignada (no declaró cambio) ──
  if (actual) {
    wgGarantizarRutas(actual);
    return { red: actual };
  }

  // ── 3) Auto: primera 10.10.X.0/24 libre ──
  const snap = await db.collection('vpn_config').get();
  const usadas = new Set();
  snap.docs.forEach((d) => {
    const s = d.data().redAntenas;
    if (s) usadas.add(s);
  });
  for (let n = 15; n <= 254; n++) {
    const subred = `10.10.${n}.0/24`;
    if (!usadas.has(subred)) {
      await ref.set({ redAntenas: subred }, { merge: true });
      wgGarantizarRutas(subred);
      console.log(`[WG] Subred asignada uid=${uid} → ${subred}`);
      return { red: subred };
    }
  }
  return { error: 'No quedan subredes de antenas disponibles.' };
}

// ── GET /wg/info — datos del servidor para autocompletar la app ──
app.get('/wg/info', async (req, res) => {
  const { apikey } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const serverPub = wgSh(`wg show ${WG_IFACE} public-key`);
    const conf = wgLeer(WG_CONF);
    const port = (conf.match(/ListenPort\s*=\s*(\d+)/) || [])[1] || '1234';
    const host = (req.headers.host || '').split(':')[0] || '5.161.88.42';
    res.json({
      ok: true,
      serverPublicKey: serverPub,
      listenPort: Number(port),
      endpoint: `${host}:${port}`,
      pool: WG_POOL,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── POST /wg/register — da de alta el peer del usuario con IP dinámica ──
app.post('/wg/register', async (req, res) => {
  const { apikey, publicKey, nombre } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  const cfg = await obtenerConfigDesdeApikey(apikey);
  if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
  const uid = cfg.propietarioUid;
  if (!wgClaveValida(publicKey)) return res.status(400).json({ error: 'publicKey inválida' });
  try {
    // El id del doc va "seguro" (sin '/' ni '+'); la PublicKey cruda queda en
    // el campo `publicKey` (ver helpers wgDocId / wgPeerPorPublicKey).
    const peerRef = db.collection('wg_peers').doc(wgDocId(publicKey));
    const existente = await wgPeerPorPublicKey(publicKey);
    if (existente) {
      const ip = existente.snap.data().ip;
      const cfgDoc = await db.collection('vpn_config').doc(uid).get();
      const red = cfgDoc.exists ? cfgDoc.data().redAntenas || null : null;
      return res.json({ ok: true, ip, address: `${ip}/32`, redAntenas: red, yaExistia: true });
    }
    const ip = await wgIpSiguienteLibre();
    if (!ip) return res.status(500).json({ error: 'Pool de IPs completo' });
    // Subred de gestión/antenas del usuario (declarada por él o auto-asignada).
    const asignada = await wgAsignarSubred(uid);
    if (asignada.error) return res.status(409).json({ error: asignada.error });
    const redAntenas = asignada.red;
    await peerRef.set({
      publicKey,
      propietarioUid: uid,
      ip,
      nombre: String(nombre || 'Técnico').slice(0, 60),
      creadoEn: admin.firestore.Timestamp.now(),
    });
    await wgRegenerarConf();
    wgAplicarPeer(publicKey, ip);
    console.log(`[WG] Peer registrado uid=${uid} ip=${ip} red=${redAntenas}`);
    res.json({ ok: true, ip, address: `${ip}/32`, redAntenas });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── POST /wg/register-mikrotik — da de alta el MikroTik como peer estático ──
// Body: { apikey, publicKey, subred?, ipLocal? }
//   · subred  → red local declarada por el usuario (ej. "192.168.10.0/24").
//               Si viene, se usa como subred de antenas validando que sea única.
//   · ipLocal → IP/puerta de enlace del MikroTik en su red local (se guarda).
app.post('/wg/register-mikrotik', async (req, res) => {
  const { apikey, publicKey, subred, ipLocal } = req.body || {};
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  const cfg = await obtenerConfigDesdeApikey(apikey);
  if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
  const uid = cfg.propietarioUid;
  if (!wgClaveValida(String(publicKey || ''))) {
    return res.status(400).json({ error: 'PublicKey inválida' });
  }
  try {
    let ip = String(cfg.mikrotikTunelIp || '').trim();
    if (!ip || !ip.startsWith(`${WG_POOL}.`)) {
      return res.status(400).json({
        error: 'Primero generá la IP del túnel del MikroTik (Config. MikroTik).',
      });
    }
    // Re-verificación EN EL SERVIDOR: si esa IP del túnel ya la tiene otro
    // equipo (p. ej. dos técnicos la generaron al mismo tiempo), se le asigna
    // la próxima IP libre del pool. La app NO es la única fuente de verdad.
    let ipReasignada = false;
    if (await wgIpTunelEnUso(ip, uid, publicKey)) {
      const libre = await wgIpSiguienteLibre();
      if (!libre) {
        return res.status(500).json({
          error:
            `La IP del túnel ${ip} ya está en uso y no quedan IPs libres ` +
            `en el pool (${WG_POOL}.2-250).`,
        });
      }
      console.log(
        `[WG] IP del túnel ${ip} ya estaba en uso → reasignada a ${libre} (uid=${uid})`
      );
      ip = libre;
      ipReasignada = true;
    }
    const dinamico = await wgPeerPorPublicKey(publicKey);
    if (dinamico) {
      return res
        .status(409)
        .json({ error: 'Esa PublicKey ya está registrada como peer dinámico.' });
    }
    // Subred de gestión/antenas: la declarada por el usuario o la auto-asignada.
    const asignada = await wgAsignarSubred(uid, subred);
    if (asignada.error) {
      return res.status(409).json({ error: asignada.error });
    }
    const red = asignada.red;

    // Si había otro MikroTik registrado con otra clave, lo damos de baja para
    // que no queden dos peers peleando la misma subred.
    const pubAnterior = String(cfg.mikrotikPublicKey || '').trim();
    if (pubAnterior && pubAnterior !== publicKey) {
      wgEscribir(WG_STATIC_FILE, wgEliminarEstatico(pubAnterior));
      wgSh(`wg set ${WG_IFACE} peer ${pubAnterior} remove`);
      console.log(`[WG] Peer anterior del MikroTik eliminado uid=${uid}`);
    }

    wgUpsertEstatico(publicKey, ip, red, 'MikroTik');
    await wgRegenerarConf();
    wgSh(`wg set ${WG_IFACE} peer ${publicKey} allowed-ips ${ip}/32,${red}`);
    wgGarantizarRutas(red);
    await db
      .collection('config_mikrotik')
      .doc(uid)
      .set(
        {
          mikrotikPublicKey: publicKey,
          mikrotikRegistradoEn: admin.firestore.Timestamp.now(),
          mikrotikTunelIp: ip,
          subredLocal: red,
          ...(ipLocal ? { ipLocal: String(ipLocal).trim().slice(0, 40) } : {}),
        },
        { merge: true }
      );
    console.log(`[WG] MikroTik registrado uid=${uid} ip=${ip} red=${red}`);
    res.json({
      ok: true,
      ip,
      ipReasignada,
      redAntenas: red,
      declarada: !!asignada.declarada,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── DELETE /wg/peers/:publicKey — da de baja el peer (solo el dueño) ──
app.delete('/wg/peers/:publicKey', async (req, res) => {
  const { apikey } = req.query;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  const cfg = await obtenerConfigDesdeApikey(apikey);
  if (!cfg) return res.status(404).json({ error: 'Sin config MikroTik' });
  const uid = cfg.propietarioUid;
  const pub = req.params.publicKey;
  try {
    // Acepta el id seguro (nuevo) y el id crudo (docs viejos).
    const encontrado = await wgPeerPorPublicKey(pub);
    if (!encontrado || encontrado.snap.data().propietarioUid !== uid) {
      return res.status(404).json({ error: 'Peer no encontrado' });
    }
    const pubReal = wgPublicKeyDeDoc(encontrado.snap);
    await encontrado.ref.delete();
    wgSh(`wg set ${WG_IFACE} peer ${pubReal} remove`);
    await wgRegenerarConf();
    console.log(`[WG] Peer eliminado uid=${uid}`);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── POST /wg/init — setup único: separa wg0.conf en interface + estáticos ──
app.post('/wg/init', async (req, res) => {
  const { apikey } = req.body;
  const valida = await validarApikey(apikey);
  if (!valida) return res.status(401).json({ error: 'No autorizado' });
  try {
    const conf = wgLeer(WG_CONF);
    if (!conf.includes('[Interface]')) return res.status(400).json({ error: 'wg0.conf inválido' });
    // Split forzado desde wg0.conf (sobrescribe interface y estáticos).
    const idx = conf.indexOf('[Peer]');
    let interfaz = (idx < 0 ? conf : conf.slice(0, idx)).trimEnd();
    const estaticos = (idx < 0 ? '' : conf.slice(idx)).trim();
    const lineas = interfaz.split('\n');
    while (lineas.length && lineas[lineas.length - 1].trim().startsWith('#')) {
      lineas.pop();
    }
    interfaz = lineas.join('\n').trim();
    wgEscribir(WG_INTERFACE_FILE, interfaz + '\n');
    wgEscribir(WG_STATIC_FILE, estaticos + '\n');
    // Regenera wg0.conf (interface + estáticos + dinámicos de Firestore).
    await wgRegenerarConf();
    res.json({ ok: true, mensaje: 'wg0.conf separado: interface + estáticos' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

console.log('[WG] Endpoints dinámicos de WireGuard cargados ✅');

// ════════════════════════════════════════════════════════════════
//  MENSAJES AUTOMÁTICOS — Se inicia en puerto 3001
//  (facturación general + cobros Starlinks)
// ════════════════════════════════════════════════════════════════
require('./mensajes');




