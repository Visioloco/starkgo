// ════════════════════════════════════════════════════════════════
//  MENSAJES AUTOMÁTICOS — StarkGo VPS
//
//  Servidor separado (puerto 3001) que maneja TODOS los mensajes
//  automáticos por WhatsApp vía Evolution API:
//
//   1. FACTURACIÓN (clientes generales del home):
//      - Recordatorios de pago (día de vencimiento − días de aviso).
//        Al enviar el recordatorio el cliente pasa a ROJO (mora),
//        tanto si el envío es automático (cron) como manual (app).
//      - Corte de servicio DESACTIVADO: lo decide el técnico
//        manualmente desde el detalle de cliente (sin cortes automáticos).
//
//   2. COBROS STARLINKS (clientes de "Mis Starlinks"):
//      - Cada cliente tiene su PROPIO día de vencimiento
//      - Se envía el cobro el día de aviso (vencimiento − aviso previo)
//      - Delay configurable entre mensajes para evitar baneos
//
//  Este archivo se inicia desde index.js con:
//    require('./mensajes');
//
//  Endpoints de prueba:
//    GET http://IP:3001/facturacion/test?paso=recordatorio&apikey=starkgo_admin_2025
//    GET http://IP:3001/facturacion/status?apikey=starkgo_admin_2025
//    GET http://IP:3001/starlinks/cobros?apikey=starkgo_admin_2025
//    GET http://IP:3001/starlinks/status?apikey=starkgo_admin_2025
// ════════════════════════════════════════════════════════════════

const express = require('express');
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Si Firebase ya está inicializado (desde index.js), reutilizarlo.
// Si no, inicializarlo aquí (por si se ejecuta standalone).
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}
const db = admin.firestore();

const app = express();
app.use(express.json());

const cron = require('node-cron');
const https = require('https');
const http = require('http');

const PUERTO = process.env.PUERTO_MENSAJES || 3001;
// Puerto del servidor principal (index.js) para encolar bloqueos MikroTik
const PUERTO_PRINCIPAL = process.env.PUERTO_PRINCIPAL || 3000;

// ── Delay base entre mensajes (facturación general) ─────────────
const DELAY_ENTRE_MENSAJES = 2500;
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Encola un bloqueo MikroTik llamando al endpoint /bloquear del index.js
async function encolarBloqueoMikrotik(apikey, ip, nombre) {
  try {
    const url = `http://127.0.0.1:${PUERTO_PRINCIPAL}/bloquear`;
    const res = await fetchJson(url, {
      body: { apikey, ip, nombre },
    });
    if (res.status === 200) {
      console.log(`[FACTURACIÓN] 🔒 Encolado bloqueo MikroTik: ${nombre} (${ip})`);
    } else {
      console.error(`[FACTURACIÓN] ⚠️ No se pudo encolar bloqueo MikroTik (${res.status}): ${nombre}`);
    }
  } catch (e) {
    console.error(`[FACTURACIÓN] ⚠️ Error encolando bloqueo MikroTik: ${e.message}`);
  }
}


// ════════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════════

function fetchJson(url, options = {}) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith('https') ? https : http;
    const req = lib.request(url, {
      method: options.method || 'POST',
      headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    if (options.body) req.write(JSON.stringify(options.body));
    req.end();
  });
}

async function enviarWhatsAppEvolution(uid, numero, mensaje) {
  try {
    const snap = await db.collection('whatsapp_instances')
      .where('uid', '==', uid)
      .limit(1)
      .get();
    if (snap.empty) {
      console.log(`[WA] uid=${uid} sin instancia Evolution configurada`);
      return false;
    }
    const inst = snap.docs[0].data();
    if (inst.status !== 'connected' && inst.status !== 'open') {
      console.log(`[WA] uid=${uid} instancia desconectada (${inst.status})`);
      return false;
    }
    const url = `${inst.serverUrl}/message/sendText/${inst.instanceName}`;
    const res = await fetchJson(url, {
      headers: { 'apikey': inst.apiKey },
      body: { number: numero, text: mensaje },
    });
    if (res.status === 200 || res.status === 201) {
      return true;
    } else {
      console.error(`[WA] Error ${res.status} enviando a ${numero}:`, JSON.stringify(res.body));
      return false;
    }
  } catch (e) {
    console.error(`[WA] Excepción enviando a ${numero}:`, e.message);
    return false;
  }
}

async function obtenerOperadores() {
  const snap = await db.collection('user').where('activo', '==', true).get();
  return snap.docs.map(d => ({ uid: d.id, ...d.data() }));
}

async function obtenerClientes(uid) {
  const snap = await db.collection('clientes').where('propietarioUid', '==', uid).get();
  return snap.docs.map(d => ({ id: d.id, ref: d.ref, ...d.data() }));
}

async function obtenerConfigEmpresa(uid) {
  const doc = await db.collection('config_empresa').doc(uid).get();
  if (!doc.exists) return null;
  return doc.data();
}

function normalizarNumero(numero, codigoPais = '+57') {
  if (!numero) return null;
  let num = numero.toString().replace(/[\s\-\(\)]/g, '');
  if (num.startsWith('0')) num = num.substring(1);
  const prefijo = codigoPais.replace('+', '');
  if (!num.startsWith(prefijo)) num = `${prefijo}${num}`;
  if (num.length < 10) return null;
  return num;
}

function formatearPesos(valor) {
  if (!valor) return '0';
  return Math.round(valor).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

// ════════════════════════════════════════════════════════════════
//  PLANTILLAS DE MENSAJES — FACTURACIÓN GENERAL
// ════════════════════════════════════════════════════════════════

function buildMensajeRecordatorio(config, cliente, diaVencimiento) {
  const nombre     = `${cliente.nombre || ''} ${cliente.apellido || ''}`.trim();
  const valorFmt   = formatearPesos(cliente.planValor);
  const planNombre = cliente.planCliente || '';
  const diasRestantes = diaVencimiento - new Date().getDate();
  let estado;
  if (diasRestantes <= 0)       estado = `🔴 *Estado:* Vence HOY`;
  else if (diasRestantes === 1) estado = `🔴 *Estado:* Vence MAÑANA, día ${diaVencimiento}`;
  else                          estado = `🟡 *Estado:* Vence en ${diasRestantes} días (día ${diaVencimiento})`;
  const template = (config.msgRecordatorio || '').trim();
  if (template) {
    return template
      .replace(/{nombre}/g,  nombre)
      .replace(/{plan}/g,    planNombre)
      .replace(/{valor}/g,   valorFmt)
      .replace(/{dia}/g,     diaVencimiento)
      .replace(/{estado}/g,  estado)
      .replace(/{empresa}/g, config.nombreEmpresa   || 'StarkGo')
      .replace(/{nequi}/g,   config.numeroNequi     || '')
      .replace(/{titular}/g, config.nombreTitular   || '')
      .replace(/{soporte}/g, config.whatsappSoporte || '')
      .replace(/{horario}/g, config.horarioSoporte  || '');
  }
  return `📢 *${config.nombreEmpresa || 'StarkGo'} — Recordatorio de Pago*\n\n` +
    `Hola *${nombre}*, te recordamos que tu factura vence el día *${diaVencimiento}* del mes.\n\n` +
    `📋 Plan: ${planNombre}\n` +
    `💳 *Valor:* $${valorFmt}\n` +
    `${estado}\n\n` +
    `💜 Nequi: ${config.numeroNequi || ''} · ${config.nombreTitular || ''}\n` +
    `Soporte: ${config.whatsappSoporte || ''}\n` +
    `${config.horarioSoporte || ''}\n\n` +
    `— *Equipo ${config.nombreEmpresa || 'StarkGo'}* 🌐`;
}

function buildMensajeVencimiento(config, cliente) {
  const nombre     = `${cliente.nombre || ''} ${cliente.apellido || ''}`.trim();
  const valorFmt   = formatearPesos(cliente.planValor);
  const planNombre = cliente.planCliente || '';
  const empresa    = config.nombreEmpresa || 'StarkGo';
  return `⚠️ *${empresa} — Aviso de Vencimiento*\n\n` +
    `Hola *${nombre}*, tu servicio de internet ha vencido hoy.\n\n` +
    `📋 Plan: ${planNombre}\n` +
    `💳 Valor: $${valorFmt}\n\n` +
    `⏳ *Tienes 2 días para realizar el pago antes de que se suspenda el servicio.*\n\n` +
    `💜 Nequi: ${config.numeroNequi || ''} · ${config.nombreTitular || ''}\n` +
    `Soporte: ${config.whatsappSoporte || ''}\n` +
    `${config.horarioSoporte || ''}\n\n` +
    `— *Equipo ${empresa}* 🌐`;
}

function buildMensajeSuspension(config, cliente) {
  const nombre     = `${cliente.nombre || ''} ${cliente.apellido || ''}`.trim();
  const valorFmt   = formatearPesos(cliente.planValor);
  const planNombre = cliente.planCliente || '';
  const template = (config.msgSuspension || '').trim();
  if (template) {
    return template
      .replace(/{nombre}/g,  nombre)
      .replace(/{plan}/g,    planNombre)
      .replace(/{valor}/g,   valorFmt)
      .replace(/{dia}/g,     '')
      .replace(/{estado}/g,  '🔴 Servicio suspendido')
      .replace(/{empresa}/g, config.nombreEmpresa   || 'StarkGo')
      .replace(/{nequi}/g,   config.numeroNequi     || '')
      .replace(/{titular}/g, config.nombreTitular   || '')
      .replace(/{soporte}/g, config.whatsappSoporte || '')
      .replace(/{horario}/g, config.horarioSoporte  || '');
  }
  return `🚫 *SERVICIO SUSPENDIDO* 🚫\n\n` +
    `Estimado/a *${nombre}*, su servicio ha sido *suspendido* por falta de pago.\n\n` +
    `📋 Plan: ${planNombre}\n` +
    `💳 Valor: $${valorFmt}\n\n` +
    `💜 Paga por Nequi: ${config.numeroNequi || ''}\n` +
    `Titular: ${config.nombreTitular || ''}\n\n` +
    `📞 Soporte: ${config.whatsappSoporte || ''}\n` +
    `${config.horarioSoporte || ''}\n\n` +
    `— *Equipo ${config.nombreEmpresa || 'StarkGo'}* 🌐`;
}

// ════════════════════════════════════════════════════════════════
//  FACTURACIÓN AUTOMÁTICA — CLIENTES GENERALES
// ════════════════════════════════════════════════════════════════

async function ejecutarRecordatorios() {
  console.log('\n[FACTURACIÓN] ═══ INICIO RECORDATORIOS ═══');
  const operadores = await obtenerOperadores();
  console.log(`[FACTURACIÓN] ${operadores.length} operadores activos`);
  for (const op of operadores) {
    try {
      const config = await obtenerConfigEmpresa(op.uid);

      // Si el operador desactivó los mensajes automáticos, no se envía nada.
      if (config && config.mensajesAutomaticos === false) {
        console.log(`[AUTOMÁTICOS] uid=${op.uid} mensajes automáticos desactivados, saltando`);
        continue;
      }
      if (!config || !config.diaVencimiento) {
        console.log(`[FACTURACIÓN] uid=${op.uid} sin config de facturación, saltando`);
        continue;
      }
      const diaHoy         = new Date().getDate();
      const diaVencimiento = Number(config.diaVencimiento);
      const diasAviso      = Number(config.diasAviso) || 1;
      const diaAviso       = diaVencimiento - diasAviso;
      if (diaHoy !== diaAviso) {
        console.log(`[FACTURACIÓN] uid=${op.uid} hoy=${diaHoy} diaAviso=${diaAviso} — no corresponde recordatorio`);
        continue;
      }
      const clientes      = await obtenerClientes(op.uid);
      const destinatarios = clientes.filter(c => c.status === 'activo' || c.status === 'mora');
      console.log(`[FACTURACIÓN] uid=${op.uid} enviando recordatorios a ${destinatarios.length} clientes`);
      let enviados = 0, errores = 0;
      for (const cliente of destinatarios) {
        const numero = normalizarNumero(cliente.numero, cliente.codigoPais || '+57');
        if (!numero) { errores++; continue; }
        const mensaje = buildMensajeRecordatorio(config, cliente, diaVencimiento);
        const ok = await enviarWhatsAppEvolution(op.uid, numero, mensaje);
        if (ok) {
          enviados++;
          await cliente.ref.update({
            ultimoRecordatorio: admin.firestore.Timestamp.now(),
            status: 'mora',
            fechaPasoMora: admin.firestore.Timestamp.now(),
          });
          console.log(`[FACTURACIÓN] ✅ Recordatorio → ${cliente.nombre} (${numero}) → en rojo (mora)`);
        } else {
          errores++;
        }
        await sleep(DELAY_ENTRE_MENSAJES);
      }
      console.log(`[FACTURACIÓN] uid=${op.uid} recordatorios: ${enviados} enviados, ${errores} errores`);
    } catch (e) {
      console.error(`[FACTURACIÓN] Error procesando operador ${op.uid}:`, e.message);
    }
  }
  console.log('[FACTURACIÓN] ═══ FIN RECORDATORIOS ═══\n');
}

async function ejecutarPasarAMora() {
  console.log('\n[FACTURACIÓN] ═══ INICIO PASAR A MORA ═══');
  const operadores = await obtenerOperadores();
  for (const op of operadores) {
    try {
      const config = await obtenerConfigEmpresa(op.uid);

      // Si el operador desactivó los mensajes automáticos, no se envía nada.
      if (config && config.mensajesAutomaticos === false) {
        console.log(`[AUTOMÁTICOS] uid=${op.uid} mensajes automáticos desactivados, saltando`);
        continue;
      }
      if (!config || !config.diaVencimiento) continue;
      const diaHoy         = new Date().getDate();
      const diaVencimiento = Number(config.diaVencimiento);
      if (diaHoy !== diaVencimiento) {
        console.log(`[FACTURACIÓN] uid=${op.uid} hoy=${diaHoy} diaVencimiento=${diaVencimiento} — no corresponde mora`);
        continue;
      }
      const clientes = await obtenerClientes(op.uid);
      const activos  = clientes.filter(c => c.status === 'activo');
      console.log(`[FACTURACIÓN] uid=${op.uid} pasando ${activos.length} clientes de 'activo' → 'mora'`);
      let pasados = 0;
      for (const cliente of activos) {
        await cliente.ref.update({ status: 'mora', fechaPasoMora: admin.firestore.Timestamp.now() });
        pasados++;
        console.log(`[FACTURACIÓN] 🟡 ${cliente.nombre} → mora`);
        const numero = normalizarNumero(cliente.numero, cliente.codigoPais || '+57');
        if (numero) {
          const msg = buildMensajeVencimiento(config, cliente);
          await enviarWhatsAppEvolution(op.uid, numero, msg);
          await sleep(DELAY_ENTRE_MENSAJES);
        }
      }
      console.log(`[FACTURACIÓN] uid=${op.uid} ${pasados} clientes pasados a mora`);
    } catch (e) {
      console.error(`[FACTURACIÓN] Error procesando operador ${op.uid}:`, e.message);
    }
  }
  console.log('[FACTURACIÓN] ═══ FIN PASAR A MORA ═══\n');
}

async function ejecutarCorteServicio() {
  console.log('\n[FACTURACIÓN] ═══ INICIO CORTE DE SERVICIO ═══');
  const operadores = await obtenerOperadores();
  for (const op of operadores) {
    try {
      const config = await obtenerConfigEmpresa(op.uid);

      // Si el operador desactivó los mensajes automáticos, no se envía nada.
      if (config && config.mensajesAutomaticos === false) {
        console.log(`[AUTOMÁTICOS] uid=${op.uid} mensajes automáticos desactivados, saltando`);
        continue;
      }
      if (!config || !config.diaVencimiento) continue;
      const diaHoy         = new Date().getDate();
      const diaVencimiento = Number(config.diaVencimiento);
      const diaCorte       = diaVencimiento + 2;
      if (diaHoy !== diaCorte) {
        console.log(`[FACTURACIÓN] uid=${op.uid} hoy=${diaHoy} diaCorte=${diaCorte} — no corresponde corte`);
        continue;
      }
      // Obtener la apikey MikroTik del operador para encolar bloqueos
      const mikrotikSnap = await db.collection('config_mikrotik')
        .where('propietarioUid', '==', op.uid)
        .limit(1)
        .get();
      const apikey = mikrotikSnap.empty ? null : mikrotikSnap.docs[0].data().vpsApiKey;
      if (!apikey) console.log(`[FACTURACIÓN] uid=${op.uid} sin config MikroTik — solo WhatsApp`);

      const clientes = await obtenerClientes(op.uid);
      const enMora   = clientes.filter(c => c.status === 'mora');
      console.log(`[FACTURACIÓN] uid=${op.uid} cortando servicio a ${enMora.length} clientes en mora`);
      for (const cliente of enMora) {
        const nombre = `${cliente.nombre || ''} ${cliente.apellido || ''}`.trim();
        const ip     = (cliente.ipatn || '').trim();
        const numero = normalizarNumero(cliente.numero, cliente.codigoPais || '+57');
        // Encolar bloqueo MikroTik vía el servidor principal (index.js)
        if (apikey && ip) {
          await encolarBloqueoMikrotik(apikey, ip, nombre);
        }
        await cliente.ref.update({ status: 'inactivo', fechaCorte: admin.firestore.Timestamp.now() });
        console.log(`[FACTURACIÓN] 🔴 ${nombre} → inactivo`);
        if (numero) {
          const msg = buildMensajeSuspension(config, cliente);
          await enviarWhatsAppEvolution(op.uid, numero, msg);
          await sleep(DELAY_ENTRE_MENSAJES);
        }
      }

      console.log(`[FACTURACIÓN] uid=${op.uid} cortes ejecutados: ${enMora.length}`);
    } catch (e) {
      console.error(`[FACTURACIÓN] Error procesando operador ${op.uid}:`, e.message);
    }
  }
  console.log('[FACTURACIÓN] ═══ FIN CORTE DE SERVICIO ═══\n');
}

// ════════════════════════════════════════════════════════════════
//  COBROS AUTOMÁTICOS STARLINKS
//
//  Cada cliente Starlink tiene su PROPIO día de vencimiento
//  (diaVencimiento) y su propio día de aviso (diasAvisoPrevio).
//  El sistema revisa cada día qué clientes tienen su día de aviso
//  hoy y les envía el cobro automáticamente.
// ════════════════════════════════════════════════════════════════

function normalizarTelStarlink(raw) {
  if (!raw) return null;
  let num = raw.toString().replace(/[^0-9]/g, '');
  if (num.length < 10) return null;
  if (num.length > 10) return num;
  return `57${num}`;
}

function formatearPesosStarlink(valor) {
  if (!valor) return '0';
  return Math.round(valor).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

function buildMensajeCobroStarlink(config, cliente) {
  const nombre     = cliente.nombreCliente || '';
  const valorFmt   = formatearPesosStarlink(cliente.montoQueCobro);
  const diaVenc    = cliente.diaVencimiento || 25;
  const empresa    = config.nombreEmpresa || 'StarkGo';
  const nequi      = config.numeroNequi || '';
  const titular    = config.nombreTitular || '';
  const soporte    = config.whatsappSoporte || '';
  const horario    = config.horarioSoporte || 'Lunes a viernes · 8am – 5pm';

  return `📡 *${empresa} — Recordatorio de Pago*\n\n` +
    `Hola *${nombre}*, esperamos que estés muy bien. 😊\n\n` +
    `Te informamos que el pago de tu servicio *Starlink* está próximo a vencer.\n\n` +
    `📅 *Fecha límite:* Día ${diaVenc} de este mes\n` +
    `💰 *Valor a cancelar:* $${valorFmt}\n\n` +
    `━━━━━━━━━━━━━━━━━\n` +
    `💳 *¿Cómo pagar?*\n` +
    `▸ *Nequi:* ${nequi}\n` +
    `▸ *Titular:* ${titular}\n` +
    `━━━━━━━━━━━━━━━━━\n\n` +
    `✅ Si ya realizaste el pago, por favor *envíanos tu comprobante* o ignora este mensaje.\n\n` +
    `📲 Soporte: ${soporte}\n` +
    `🕐 Horario: ${horario}\n\n` +
    `— *Equipo ${empresa}* 🌐`;
}

async function obtenerClientesStarlinks(uid) {
  const snap = await db.collection('starlink_clientes_pago')
    .where('propietarioUid', '==', uid)
    .get();
  return snap.docs.map(d => ({ id: d.id, ref: d.ref, ...d.data() }));
}

async function ejecutarCobrosStarlinks() {
  console.log('\n[STARLINKS] ═══ INICIO COBROS AUTOMÁTICOS ═══');
  const operadores = await obtenerOperadores();
  console.log(`[STARLINKS] ${operadores.length} operadores activos`);
  const diaHoy = new Date().getDate();

  for (const op of operadores) {
    try {
      const config = await obtenerConfigEmpresa(op.uid);

      // Si el operador desactivó los mensajes automáticos, no se envía nada.
      if (config && config.mensajesAutomaticos === false) {
        console.log(`[AUTOMÁTICOS] uid=${op.uid} mensajes automáticos desactivados, saltando`);
        continue;
      }
      if (!config) {
        console.log(`[STARLINKS] uid=${op.uid} sin config de empresa, saltando`);
        continue;
      }

      // Si el operador no activó los cobros automáticos, saltar
      if (config.cobroAutoStarlinks !== true) {
        console.log(`[STARLINKS] uid=${op.uid} cobros automáticos desactivados, saltando`);
        continue;
      }

      const clientes = await obtenerClientesStarlinks(op.uid);
      // Cada cliente tiene su PROPIO día de vencimiento (diaVencimiento)
      // y su propio día de aviso (diaVencimiento - diasAvisoPrevio).
      // Hoy solo se envían cobros a los clientes cuyo día de aviso coincide con hoy.
      const destinatarios = clientes.filter(c => {
        if (c.estado === 'inactivo') return false;
        const diaVenc = Number(c.diaVencimiento) || 1;
        const diasAviso = Number(c.diasAvisoPrevio) || 2;
        let diaAviso = diaVenc - diasAviso;
        if (diaAviso < 1) diaAviso = 1;
        return diaAviso === diaHoy;
      });
      console.log(`[STARLINKS] uid=${op.uid} hoy=${diaHoy} → ${destinatarios.length} clientes Starlink con aviso hoy`);

      // Delay configurable (por defecto 30 segundos)
      const delayMs = (Number(config.cobroAutoDelaySeg) || 30) * 1000;

      let enviados = 0, errores = 0;
      for (const cliente of destinatarios) {
        const numero = normalizarTelStarlink(cliente.telefono);
        if (!numero) {
          console.log(`[STARLINKS] ⚠️ ${cliente.nombreCliente} sin teléfono válido, saltando`);
          errores++;
          continue;
        }

        const mensaje = buildMensajeCobroStarlink(config, cliente);
        const ok = await enviarWhatsAppEvolution(op.uid, numero, mensaje);

        if (ok) {
          enviados++;
          await cliente.ref.update({
            estado: 'pendiente',
            ultimoCobroEnviado: admin.firestore.Timestamp.now(),
          });
          console.log(`[STARLINKS] ✅ Cobro → ${cliente.nombreCliente} (${numero})`);
        } else {
          errores++;
          console.log(`[STARLINKS] ❌ Falló → ${cliente.nombreCliente} (${numero})`);
        }

        // ⏱️ Lazo configurable entre mensajes para evitar baneos
        await sleep(delayMs);
      }
      console.log(`[STARLINKS] uid=${op.uid} cobros: ${enviados} enviados, ${errores} errores`);
    } catch (e) {
      console.error(`[STARLINKS] Error procesando operador ${op.uid}:`, e.message);
    }
  }
  console.log('[STARLINKS] ═══ FIN COBROS AUTOMÁTICOS ═══\n');
}

// ════════════════════════════════════════════════════════════════
//  CRON JOBS
// ════════════════════════════════════════════════════════════════

// Recordatorios: todos los días a la 1:00 PM
cron.schedule('0 13 * * *', async () => {
  console.log('[CRON] Ejecutando recordatorios...');
  try { await ejecutarRecordatorios(); }
  catch (e) { console.error('[CRON] Error en recordatorios:', e.message); }
});

// ⚠️ CORTE Y MORA AUTOMÁTICOS DESACTIVADOS
// El técnico decide el corte manualmente desde el detalle de cliente.
// El estado en rojo (mora) se asigna al ENVIAR el recordatorio
// (automático en este cron, o manual desde el Home / lista de clientes).
//
// cron.schedule('0 14 * * *', async () => {
//   console.log('[CRON] Ejecutando pasar a mora...');
//   try { await ejecutarPasarAMora(); }
//   catch (e) { console.error('[CRON] Error en mora:', e.message); }
// });
//
// cron.schedule('0 14 * * *', async () => {
//   console.log('[CRON] Ejecutando corte de servicio...');
//   try { await ejecutarCorteServicio(); }
//   catch (e) { console.error('[CRON] Error en corte:', e.message); }
// });

// Cobros Starlinks: todos los días a las 8:00 AM
// Cada cliente tiene su PROPIO día de vencimiento.
// El sistema revisa cada día qué clientes tienen su día de aviso hoy.
cron.schedule('0 8 * * *', async () => {
  console.log('[CRON] Verificando cobros automáticos Starlinks (por día de vencimiento de cada cliente)...');
  try {
    await ejecutarCobrosStarlinks();
  } catch (e) {
    console.error('[CRON] Error en cobros Starlinks:', e.message);
  }
});

// ════════════════════════════════════════════════════════════════
//  ENDPOINTS DE PRUEBA
// ════════════════════════════════════════════════════════════════

// GET /facturacion/test?paso=recordatorio|mora|corte&apikey=starkgo_admin_2025
app.get('/facturacion/test', async (req, res) => {
  const { paso, apikey } = req.query;
  if (apikey !== 'starkgo_admin_2025') return res.status(401).json({ error: 'No autorizado' });
  try {
    if      (paso === 'recordatorio') await ejecutarRecordatorios();
    else if (paso === 'mora')         await ejecutarPasarAMora();
    else if (paso === 'corte')        await ejecutarCorteServicio();
    else return res.status(400).json({ error: 'paso inválido: recordatorio | mora | corte' });
    res.json({ ok: true, paso, ejecutado: new Date().toISOString() });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET /facturacion/status?apikey=starkgo_admin_2025
app.get('/facturacion/status', async (req, res) => {
  const { apikey } = req.query;
  if (apikey !== 'starkgo_admin_2025') return res.status(401).json({ error: 'No autorizado' });
  try {
    const hoy        = new Date();
    const operadores = await obtenerOperadores();
    const resumen    = [];
    for (const op of operadores) {
      const config   = await obtenerConfigEmpresa(op.uid);
      const clientes = await obtenerClientes(op.uid);
      resumen.push({
        uid:            op.uid,
        nombre:         `${op.nombre || ''} ${op.apellido || ''}`.trim(),
        diaVencimiento: config?.diaVencimiento || null,
        diasAviso:      config?.diasAviso || 1,
        totalClientes:  clientes.length,
        activos:        clientes.filter(c => c.status === 'activo').length,
        mora:           clientes.filter(c => c.status === 'mora').length,
        inactivos:      clientes.filter(c => c.status === 'inactivo').length,
      });
    }
    res.json({ fecha: hoy.toISOString(), hoyDia: hoy.getDate(), operadores: resumen });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET /starlinks/cobros?apikey=starkgo_admin_2025
app.get('/starlinks/cobros', async (req, res) => {
  const { apikey } = req.query;
  if (apikey !== 'starkgo_admin_2025') return res.status(401).json({ error: 'No autorizado' });
  try {
    await ejecutarCobrosStarlinks();
    res.json({ ok: true, ejecutado: new Date().toISOString() });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET /starlinks/status?apikey=starkgo_admin_2025
app.get('/starlinks/status', async (req, res) => {
  const { apikey } = req.query;
  if (apikey !== 'starkgo_admin_2025') return res.status(401).json({ error: 'No autorizado' });
  try {
    const hoy        = new Date();
    const operadores = await obtenerOperadores();
    const resumen    = [];
    for (const op of operadores) {
      const config   = await obtenerConfigEmpresa(op.uid);
      const clientes = await obtenerClientesStarlinks(op.uid);
      resumen.push({
        uid:            op.uid,
        nombre:         `${op.nombre || ''} ${op.apellido || ''}`.trim(),
        cobroAuto:      config?.cobroAutoStarlinks || false,
        delaySeg:       config?.cobroAutoDelaySeg || 30,
        totalStarlinks: clientes.length,
        conAvisoHoy:    clientes.filter(c => {
          if (c.estado === 'inactivo') return false;
          const diaVenc = Number(c.diaVencimiento) || 1;
          const diasAviso = Number(c.diasAvisoPrevio) || 2;
          let diaAviso = diaVenc - diasAviso;
          if (diaAviso < 1) diaAviso = 1;
          return diaAviso === hoy.getDate();
        }).length,
      });
    }
    res.json({ fecha: hoy.toISOString(), hoyDia: hoy.getDate(), operadores: resumen });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET / (raíz)
app.get('/', (req, res) => {
  res.json({
    status: 'StarkGo Mensajes API',
    puerto: PUERTO,
    endpoints: [
      'GET /facturacion/test?paso=recordatorio|mora|corte&apikey=...',
      'GET /facturacion/status?apikey=...',
      'GET /starlinks/cobros?apikey=...',
      'GET /starlinks/status?apikey=...',
    ],
  });
});

// ════════════════════════════════════════════════════════════════
//  INICIAR SERVIDOR
// ════════════════════════════════════════════════════════════════

app.listen(PUERTO, () => {
  console.log(`[MENSAJES] Servidor de mensajes automáticos en puerto ${PUERTO} ✅`);
  console.log('[MENSAJES] Facturación: recordatorios 1PM · mora 2PM · corte 2PM');
  console.log('[MENSAJES] Starlinks: cobros 8AM (por día de vencimiento de cada cliente)');
  console.log('[MENSAJES] Test facturación: GET /facturacion/test?paso=recordatorio&apikey=starkgo_admin_2025');
  console.log('[MENSAJES] Test starlinks: GET /starlinks/cobros?apikey=starkgo_admin_2025');
});


