# 📦 Instrucciones para el VPS — Plan "Solo Vouchers"

> 🔗 **Túnel WireGuard / VPN:** vive en **`CONFIGURAR_VPN.md`**. Este documento
> es sólo del alta de planes (campo `plan`, vouchers, etc.).

Este documento explica los cambios que debes hacer en tu **VPS** (servidor Node.js en `http://5.161.88.42:3000`) para que el nuevo plan **"Solo Vouchers"** funcione correctamente.

> 💱 **Moneda de Mercado Pago:** la cuenta de Mercado Pago es de **Colombia**, por lo que
> el cobro se hace en **COP (pesos colombianos)**. En `functions/index.js`, cada plan tiene:
> - `precio` → valor en **USD** (lo usa **PayPal**)
> - `precioCop` → valor en **COP** (lo usa **Mercado Pago**)
>
> Ajusta los `precioCop` al valor que quieras cobrar. (Si tu cuenta fuera de otro país,
> cambia `MP_CURRENCY` a la moneda correspondiente: `MXN`, `ARS`, `BRL`, etc.)

---

## 1. ¿Qué hace la app Flutter?

La app ya está lista. Cuando un usuario compra un plan, la app envía al VPS estos datos en el body de `POST /mp/crear-preferencia`:

```json
{
  "planId": "v1m",          // o "1m", "3m", "6m", "1a", "v3m", "v6m", "v1a"
  "nombre": "Nombre Usuario",
  "tipo": "vouchers",       // "completo" | "vouchers"
  "meses": 1
}
```

- `tipo: "completo"` → planes normales (1m, 3m, 6m, 1a)
- `tipo: "vouchers"` → planes solo vouchers (v1m, v3m, v6m, v1a)

---

## 2. Cambios necesarios en el VPS

### 2.1. Agregar los planes "Solo Vouchers" al catálogo

En el archivo donde defines los planes (similar a `PLANES` en `functions/index.js`), agrega los nuevos planes:

```js
const PLANES = {
  // Planes completos (acceso a toda la app)
  "1m":  { titulo: "StarkGo · 1 Mes",    precio: 15,  meses: 1,  tipo: "completo" },
  "3m":  { titulo: "StarkGo · 3 Meses",  precio: 39,  meses: 3,  tipo: "completo" },
  "6m":  { titulo: "StarkGo · 6 Meses",  precio: 69,  meses: 6,  tipo: "completo" },
  "1a":  { titulo: "StarkGo · 1 Año",    precio: 120, meses: 12, tipo: "completo" },

  // Planes "Solo Vouchers" (solo módulo MikroTik Local)
  "v1m": { titulo: "StarkGo · Solo Vouchers 1 Mes",    precio: 3,  meses: 1,  tipo: "vouchers" },
  "v3m": { titulo: "StarkGo · Solo Vouchers 3 Meses",  precio: 8,  meses: 3,  tipo: "vouchers" },
  "v6m": { titulo: "StarkGo · Solo Vouchers 6 Meses",  precio: 15, meses: 6,  tipo: "vouchers" },
  "v1a": { titulo: "StarkGo · Solo Vouchers 1 Año",    precio: 30, meses: 12, tipo: "vouchers" },
};
```

### 2.2. Guardar el campo `plan` en Firestore al confirmar el pago

Cuando el pago es aprobado y actualizas el documento del usuario en Firestore, **agrega el campo `plan`** como un mapa con el tipo de plan. Busca el bloque donde haces `db.collection("user").doc(uid).update({...})` y modifícalo así:

```js
// Obtener el tipo de plan (del body de la preferencia o del catálogo)
const planInfo = PLANES[planId] ?? { tipo: "completo", meses: 1 };
const tipoPlan = planInfo.tipo; // "completo" | "vouchers"

await db.collection("user").doc(uid).update({
  planMembresia: planId,
  mesesMembresia: meses,
  fechaVencimiento: nuevaFecha,
  activo: true,
  ultimaRenovacion: FieldValue.serverTimestamp(),
  ultimoPagoId: paymentId,
  ultimoPagoMonto: payment.transaction_amount,

  // ✅ NUEVO: campo `plan` con el tipo de plan
  plan: {
    tipo: tipoPlan,        // "completo" | "vouchers"
    planId: planId,        // "1m", "v3m", etc.
    meses: meses,          // 1, 3, 6, 12
  },
});
```

> **Importante:** El campo `plan` debe ser un **mapa** (objeto) con al menos la clave `tipo`. La app Flutter lo lee así:
> ```dart
> final planMap = data['plan'];
> if (planMap is Map) {
>   tipo = (planMap['tipo'] ?? 'completo').toString();
> }
> ```

### 2.3. (Opcional) Guardar el tipo en `pagos_pendientes`

Si quieres registrar el tipo de plan en el historial de pagos, agrega `tipo` al crear la preferencia:

```js
await db.collection("pagos_pendientes").add({
  uid,
  planId,
  meses: plan.meses,
  precio: plan.precio,
  tipo: plan.tipo,          // ✅ NUEVO
  preferenceId: result.id,
  estado: "pendiente",
  creadoEn: FieldValue.serverTimestamp(),
});
```

---

## 3. Resumen de lo que hace la app con el campo `plan`

| Campo en Firestore | Valor | Efecto en la app |
|---|---|---|
| `plan.tipo` | `"completo"` | Acceso a toda la app (clientes, planes, informes, etc.) |
| `plan.tipo` | `"vouchers"` | Solo se muestra el módulo MikroTik Local (Conexión Local, Config. VPS, Velocidades) |

- Si el campo `plan` **no existe** o no tiene `tipo`, la app asume `"completo"` (comportamiento actual).
- Los usuarios existentes con `planMembresia` (1m, 3m, 6m, 1a) siguen teniendo acceso completo.

---

## 4. Verificación rápida

Después de hacer los cambios en el VPS:

1. Reinicia el servidor Node.js.
2. Compra un plan "Solo Vouchers" desde la app.
3. Verifica en Firestore que el documento `user/{uid}` tenga:
   ```json
   {
     "planMembresia": "v1m",
     "plan": { "tipo": "vouchers", "planId": "v1m", "meses": 1 },
     "fechaVencimiento": "..."
   }
   ```
4. Abre la app → el Home debe mostrar la pantalla "Plan Solo Vouchers" con accesos rápidos al módulo MikroTik.

---

## 5. Cola con confirmación (v2.7) — Simple Queues y blindaje del hotspot

> ⚠️ **Subí `functions/index.js` al VPS y reiniciá el servidor Node.** Si en
> `http://5.161.88.42:3000/` NO aparece `endpoints_cola`, el VPS sigue con la
> versión vieja y los arreglos de abajo no están activos.

**Qué estaba pasando:** `/cola` borraba la cola apenas el MikroTik la
descargaba. Si el `/import` fallaba en UNA línea (un nombre con comillas, un
`$`, un `;`, un `remove` de algo que no existía), RouterOS cortaba el archivo
completo, **ningún** comando se aplicaba y la cola igual quedaba vacía: la
Simple Queue y el `ip-binding bypassed` nunca se creaban y nadie se enteraba.

**Qué hace ahora el VPS:**

| Cambio | Efecto |
|---|---|
| El lote queda **en vuelo** hasta que el MikroTik confirma con `GET /cola/ack` | Si el `/import` se corta, no hay ack y el VPS **reintenta solo** |
| Todos los comandos son **idempotentes** | Reenviar no duplica address-list, bindings ni queues |
| Los valores se **sanitizan** (sin `"`, `$`, `;`, saltos de línea) | Un nombre raro ya no rompe el `/import` completo |
| Comandos nuevos se **suman al lote en vuelo** | No esperan un ciclo extra del scheduler |
| `GET /cola/estado?apikey=...` | Diagnóstico: pendientes / en vuelo / última confirmación |
| `POST /encolar` (lista blanca de acciones) | La app ya puede encolar sin 404 |
| `POST /dashboard/reportar` | El script `starkgo-dashboard-report` ya no pega a un 404 |
| `/dashboard/resumen` con respaldo | Si el VPS no puede entrar por REST, usa el último reporte del router |

**La confirmación viaja dentro del propio `.rsc`** (últimas dos líneas), así que
funciona incluso con schedulers ya creados:

```
/tool fetch url="http://5.161.88.42:3000/cola/ack?apikey=...&token=..." mode=http dst-path=starkgo-ack.tmp
/file remove starkgo-ack.tmp
```

`COLA_TTL_MS` (por defecto 10 minutos, variable de entorno) es el plazo para
reintentar. El scheduler del MikroTik consulta cada 1-5 min, así que 10 min
alcanza para no reintentar de más.

**Cómo verificarlo:** en la app → **Config. MikroTik** → tarjeta
**"Cola del VPS"** → botón **Verificar**: debe decir *"Todo aplicado en el
router"*. Si dice *"Comandos pendientes"* o *"En vuelo"*, el MikroTik todavía
no bajó/confirmó los comandos (revisá el scheduler `starkgo-scheduler` y la
API Key).

### ¿Alcanza con subir `index.js`?

| Arreglo | ¿Solo con `index.js` en el VPS? |
|---|---|
| La Simple Queue ya no se pierde (lote en vuelo + ack + reintento) | ✅ Sí |
| Los nombres con `"`/`$`/`;` ya no rompen el `/import` | ✅ Sí |
| `/dashboard/reportar` y `/dashboard/resumen` con respaldo | ✅ Sí |
| El consumo ya no se cuelga (timeout de `obtenerQueuesMikroTik`) | ✅ Sí |
| **Blindaje del hotspot automático al crear/reactivar cliente** | ❌ Necesita la **APK nueva** (el "siempre blindar" está en la app) |
| Aviso cuando el VPS no acepta el comando (API Key/VPS caído) | ❌ APK nueva |
| Tarjeta **"Cola del VPS → Verificar"** | ❌ APK nueva |
| Comando del firewall con `place-before=0` y el "blinda las IPs" tolerante | ❌ APK nueva (o copialos de este doc) |
| Fix de la mora automática (`Timestamp`) | ❌ APK nueva |

> 🔁 **Orden de la velocidad (importante):** el `index.js` nuevo entiende a las
> dos versiones de la app. La **APK nueva** manda `ordenVelocidad:
> 'subida-bajada'` y sus valores ya vienen bien; la **APK vieja** no manda ese
> campo y el VPS respeta su orden invertido. En los dos casos la Simple Queue
> queda con `max-limit = subida/bajada` correcto, así que **a nadie se le dan
> vuelta los megas** mientras actualizás los teléfonos.
