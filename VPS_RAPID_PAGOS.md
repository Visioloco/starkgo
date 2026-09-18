# 📦 Módulo RAPID (antes Rapyd) — pagos con tarjeta/PSE

PayPal quedó **desactivado** por ahora (solo se ocultó el botón: `_kPayPalHabilitado = false`
en `activar_membresia_widget.dart` y `renovar_membresia_widget.dart`). En su lugar
ahora está **Rapid** (la marca nueva de Rapyd), junto a **Mercado Pago**.

> ⚠️ Las llaves `rak_...` / `rsk_...` son de **Rapyd/Rapid**, no de PayU Latam.
> (PayU Latam sigue usando `apiKey` + `apiLogin`.) Si en tu panel figura como
> "Rapid", es este mismo módulo.

---

## 1. Endpoints nuevos en el VPS (puerto 3000)

| Endpoint | Qué hace |
|---|---|
| `POST /rapid/crear-orden` | La app lo llama con tu token. Crea el **checkout hospedado** y devuelve `{ initPoint }` (la URL del checkout). |
| `GET /rapid/retorno` | A dónde vuelve el cliente tras pagar. Verifica el pago, **activa la membresía** y devuelve a la app con `starkgo://pago/exitoso`. |
| `GET /rapid/error` / `/rapid/cancelado` | Vuelven a la app como `fallido` / `pendiente`. |
| `POST /rapid/webhook` | Notificación de Rapid (respaldo). Verifica la firma y activa la membresía. |
| `GET /rapid/diag` | **Diagnóstico**: abre esta URL en el navegador y confirma que las llaves funcionan. |

### Configuración (variables de entorno, todas opcionales)

> 🔐 **Nunca pongas las claves reales en el código ni en git** (este repo es
> público). Ponelas en las **variables de entorno** del VPS o en
> `functions/credenciales.local.json` (ese archivo está en `.gitignore`).
> Ver `functions/credenciales.local.ejemplo.json`.

```bash
RAPID_ACCESS_KEY=rak_TU_ACCESS_KEY        # panel de Rapid (NO subir a git)
RAPID_SECRET_KEY=rsk_TU_SECRET_KEY        # panel de Rapid (NO subir a git)
RAPID_MODE=sandbox          # 'sandbox' (pruebas) | 'live' (cobros reales)
RAPID_COUNTRY=CO            # país del comercio
RAPID_CURRENCY=COP          # ⚠️ Colombia solo acepta COP en esta cuenta
RAPID_VPS_URL=http://5.161.88.42:3000
RAPID_WEBHOOK_URL=http://5.161.88.42:3000/rapid/webhook
```

Si no definís nada, se usan los valores de arriba tal cual (sandbox).

---

## 1.bis 🔄 CONFIG DINÁMICA (Firestore) — pasás a producción sin tocar el VPS

Las llaves y el modo viven en **Firestore**, no en el código:

```
config_pagos/rapid  →
{
  "produccion": false,           // false = SANDBOX (botón OCULTO) · true = PRODUCCIÓN (botón VISIBLE)
  "modo": "sandbox",             // 'sandbox' | 'live' → a qué host de Rapid apunta
  "accessKey": "rak_...",        // panel de Rapid
  "secretKey": "rsk_...",        // panel de Rapid
  "pais": "CO",
  "moneda": "COP",
  "webhookUrl": "http://5.161.88.42:3000/rapid/webhook",
  "actualizado": <timestamp>
}
```

- **El VPS la CREA SOLA** la primera vez con los valores de sandbox → no tenés que
  crear nada a mano: subí el `index.js`, reiniciá y el documento aparece.
- **Se relee cada 15 segundos** (`PAGOS_TTL_SEG`) → cambiás algo en Firebase y
  aplica enseguida, **sin reiniciar el VPS**.
- La app **no** lee las llaves. El VPS publica un **espejo público** (sin
  secretos) en `config_publica/pasarelas`:

```json
{ "rapid": { "produccion": true, "modo": "live" }, "actualizado": <timestamp> }
```

  y la app **escucha ese documento en TIEMPO REAL** (listener de Firestore) →
  el botón de Rapid aparece/desaparece **al instante**, sin reinstalar nada.
  Además, por si el listener no está disponible, la app también recibe el dato
  por `GET /precios` como respaldo.

### ⚡ En vivo (así queda el ciclo)

```
Editás config_pagos/rapid  →  VPS lo lee (≤15 s)  →  publica config_publica/pasarelas
                                                              ↓ (tiempo real)
                                              app: el botón aparece/desaparece al instante
```

### 🔴 REGLA DE FIRESTORE OBLIGATORIA

`config_pagos` guarda llaves **secretas** (nadie las lee desde la app);
`config_publica` es solo banderas (la app sí la lee). En Firestore:

```
match /config_pagos/{doc} {
  allow read, write: if false;   // solo el servidor (ahí están las llaves)
}

match /config_publica/{doc} {
  allow read: if true;           // la app necesita leer el espejo
  allow write: if false;         // lo escribe solo el VPS
}
```

> ⚠️ Si tus reglas actuales dejan leer "todo" desde el cliente, la `secretKey`
> de `config_pagos` quedaría expuesta. Con estos dos bloques queda cerrado.
> (Si `config_publica` no se puede leer, la app igual funciona: usa el dato que
> le manda el VPS por `/precios`, solo que con unos segundos de retraso.)

---

## 2. Pasos para que funcione (una sola vez)

1. **Subir `functions/index.js` al VPS** y reiniciar el servicio.
   En el arranque debe aparecer:
   ```
   [RAPID] Cargado (modo=sandbox, host=sandboxapi.rapyd.net, webhook=http://5.161.88.42:3000/rapid/webhook)
   ```
2. **Verificar las llaves**: abrí en el navegador
   `http://5.161.88.42:3000/rapid/diag`
   → debe responder `{"ok":true, ...}` con la lista de métodos disponibles para CO/COP.
3. **Registrar el webhook en el panel de Rapid** (Developers → Webhooks):
   ```
   http://5.161.88.42:3000/rapid/webhook
   ```
   > 🔴 **Importante**: la firma del webhook se calcula sobre **esa URL exacta**.
   > Si el panel te da otra URL (con `https`, otro dominio o un puerto distinto),
   > definí `RAPID_WEBHOOK_URL` con el valor real en el VPS.
4. **Probar en sandbox**: app → Renovar membresía → elegí un plan → **Pagar con
   Rapid (PayU)** → se abre el checkout `sandboxcheckout.rapyd.net` → pagá con una
   [tarjeta de prueba de Rapid](https://docs.rapyd.net) → la app debe quedar en la
   pantalla de pago exitoso y la membresía renovada.
5. **Pasar a producción**: `RAPID_MODE=live` con las llaves **live** del panel
   (las `live` también empiezan con `rak_`/`rsk_`, pero son otras).

---

## 3. Cómo funciona la firma (por si hay que depurar)

Cada request se firma así (idéntico al SDK oficial de Rapid):

```
signature = base64( HMAC_SHA256_HEX( secret,
              method.toLowerCase() + path + salt + timestamp +
              access_key + secret + body ) )
```

Y los webhooks entrantes:

```
signature = base64( HMAC_SHA256_HEX( secret,
              URL_del_webhook + salt + timestamp + access_key + secret + raw_body ) )
```

Headers que se mandan: `access_key`, `salt`, `timestamp`, `signature`, `idempotency`.

---

## 4. Registro de las órdenes

Cada checkout queda en Firestore en la colección **`rapid_ordenes`**:

```json
{
  "uid": "…",
  "planId": "1m",
  "monto": 60000,
  "moneda": "COP",
  "estado": "NEW | PAGADO",
  "modo": "sandbox",
  "paymentId": "payment_…",
  "creadoEn": "…",
  "pagadoEn": "…"
}
```

La activación es **idempotente** (`pago_<paymentId>`): si llegan el retorno y el
webhook de la misma compra, la membresía se renueva **una sola vez**.

---

## 5. Verificación de pagos (la parte crítica) 🔎

El retorno del checkout **no siempre trae el id en la URL**, así que el VPS
verifica el pago **por el pago mismo**, no por la URL:

| Endpoint | Qué hace |
|---|---|
| `POST /rapid/verificar` | (con token de Firebase) Busca en Rapid los pagos **acreditados** de ese usuario y activa la membresía. Lo usa el botón **"Verificar estado"** de la app. |
| `GET /rapid/retorno` | Además de mirar el `checkout_id`/`payment_id` que venga en la URL, si no logra identificar nada **busca el pago acreditado de las últimas 6 h** y lo activa. |

**Regla de oro**: un pago cuenta si en Rapid tiene `paid: true` **o**
`status: "CLO"`, y **no** está devuelto (`refunded: false`).

### Si un pago quedó "pendiente" en la app

Entrá a la pantalla de pago pendiente y tocá **"Verificar estado"**: el VPS
consulta Rapid y activa lo que corresponda. En los logs del VPS vas a ver:

```
[RAPID] Retorno query={"checkout_id":"checkout_..."}     → llegó el id en la URL
[RAPID] Retorno: activado por respaldo → [{"uid":"...","planId":"1a"}]
[RAPID] Verificar uid=XYZ plan=v1m → activados=1
[RAPID] ⚠️ Firma de webhook inválida → revisá RAPID_WEBHOOK_URL
```

---

## 6. Mientras el webhook no esté configurado
Todo funciona igual: **el retorno + el botón "Verificar estado"** cubren el
caso. El webhook solo agrega la activación automática cuando el cliente
**cierra la app** después de pagar. Conviene configurarlo cuando puedas:

```
http://5.161.88.42:3000/rapid/webhook
```

---

## 7. 🚀 Cómo pasar a PRODUCCIÓN (resumen)

**¿Es solo poner las llaves de producción? Sí, pero son 4 cosas:**

1. En el panel de Rapid: **registrar el webhook de producción** →
   `http://5.161.88.42:3000/rapid/webhook`
   *(el sandbox y el live tienen su propia lista de webhooks)*
2. En **Firestore → `config_pagos/rapid`** (aplica solo en ~1 minuto):
   ```json
   {
     "produccion": true,
     "modo": "live",
     "accessKey": "rak_... (producción)",
     "secretKey": "rsk_... (producción)",
     "webhookUrl": "http://5.161.88.42:3000/rapid/webhook"
   }
   ```
3. **No hace falta recompilar la app**: el botón aparece solo (la app lee
   `produccion` del VPS cada 2 minutos).
4. Que la **cuenta esté aprobada/verificada** por Rapid: mientras esté en
   revisión, los pagos quedan "pendiente" hasta que aprueben (eso no se
   soluciona con código).

### Los 3 combos posibles

| `produccion` | `modo` | Llaves | Botón en la app | Cobra con |
|---|---|---|---|---|
| `false` | `sandbox` | sandbox | **oculto** | — (nadie puede pagar) |
| `true` | `sandbox` | sandbox | **visible** | sandbox (para probar el flujo completo) |
| `true` | `live` | **live** | **visible** | **dinero real** ✅ |

### Verificar que quedó bien

```
http://5.161.88.42:3000/rapid/diag?refrescar=1
```

Debe responder `"produccion": true`, `"modo": "live"`, `"host": "api.rapyd.net"`
y las llaves **enmascaradas** (`rak_9A4F…5772`).

> 💡 Si el botón no aparece y la config está en `true`: esperá ~2 minutos (la app
> relee la config) o cerrá y abrí la app.

