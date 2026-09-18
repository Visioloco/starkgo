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
  const yaEsta = colas[apikey].some(
    (c) => c.nombre === cmd.nombre && c.accion === cmd.accion && String(c.ip || '') === ip
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
  'limitarMegas',
  'pppoeCrear',
  'pppoeEliminar',
]);
const CAMPOS_ENCOLABLES = [
  'ip',
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

const mpClient = new MercadoPagoConfig({
  accessToken: 'APP_USR-2192060784339362-042316-e4103c6eba088eef4bf579cc39cff8cb-166839613',
});

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
      // La app usa esto para mostrar/ocultar el botón de Rapid:
      // produccion=false → botón OCULTO · true → botón VISIBLE.
      pasarelas: {
        rapid: { produccion: RAPID_CFG.produccion, modo: RAPID_CFG.modo },
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
    res.json({ initPoint: result.init_point, sandboxInitPoint: result.sandbox_init_point });
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
      const [uid, planId] = pago.external_reference.split('|');
      const plan = PLANES_MP[planId];
      if (!uid || !plan) return res.sendStatus(200);
      const userRef = db.collection('user').doc(uid);
      const userDoc = await userRef.get();
      const tsActual = userDoc.data()?.fechaVencimiento?.toDate();
      const base = (tsActual && tsActual > new Date()) ? tsActual : new Date();
      const nuevaFecha = new Date(base);
      nuevaFecha.setMonth(nuevaFecha.getMonth() + plan.meses);

      // Actualizar TODOS los campos de membresía
      await userRef.update({
        fechaVencimiento: admin.firestore.Timestamp.fromDate(nuevaFecha),
        planMembresia: planId,           // '1m' | '3m' | '6m' | '1a' | 'v1m' | 'v3m' | 'v6m' | 'v1a'
        activo: true,
        plan: {
          tipo: plan.tipo,               // 'completo' | 'vouchers'
          nombre: plan.titulo,
          meses: plan.meses,
          precio: plan.precio,
          actualizado: admin.firestore.Timestamp.now(),
        },
      });
      console.log(`[MP] ✅ uid=${uid} renovado hasta ${nuevaFecha.toISOString()} plan=${planId} tipo=${plan.tipo}`);
    }
    res.sendStatus(200);
  } catch (e) {
    console.error('[MP] Error webhook:', e.message);
    res.sendStatus(500);
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
  const actual = JSON.stringify({
    produccion: RAPID_CFG.produccion,
    modo: RAPID_CFG.modo,
  });
  if (actual === espejoPublicado) return;
  try {
    await db
      .collection('config_publica')
      .doc('pasarelas')
      .set(
        {
          rapid: {
            produccion: RAPID_CFG.produccion,
            modo: RAPID_CFG.modo,
          },
          actualizado: admin.firestore.Timestamp.now(),
        },
        { merge: true }
      );
    espejoPublicado = actual;
    console.log(
      `[PAGOS] Espejo público actualizado → rapid.produccion=${RAPID_CFG.produccion}`
    );
  } catch (e) {
    console.warn('[PAGOS] No pude publicar el espejo público:', e.message);
  }
}

function hostDeModo(modo) {
  return String(modo).toLowerCase() === 'live' ? RAPID_HOST_LIVE : RAPID_HOST_SANDBOX;
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
    console.log(
      `[RAPID] Verificar uid=${uid} plan=${planId || 'cualquiera'} → activados=${activados.length}`
    );
    res.json({
      ok: true,
      pagado: activados.length > 0,
      activados: activados.length,
      planes: activados.map((a) => a.planId),
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




