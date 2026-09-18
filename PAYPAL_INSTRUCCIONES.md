# 💳 Instrucciones — Pago con PayPal

PayPal quedó integrado **igual que Mercado Pago**: misma pantalla de renovación,
mismo WebView (`PagoWebViewPage`) y misma respuesta `{ initPoint }`, solo cambia
la pasarela.

La app **ya está lista**. Cuando el usuario renueva, si elige **PayPal** la app
llama a `POST /paypal/crear-orden` en vez de `/mp/crear-preferencia`.

---

## 1. ¿Qué debes configurar en el VPS?

Las credenciales **ya NO van en el código** (este repo es público). Se leen, en
este orden: **variables de entorno** → `functions/credenciales.local.json`
(archivo local, está en `.gitignore`) → Firestore `config_pagos/rapid`.

```bash
# variables de entorno del VPS (recomendado)
PAYPAL_CLIENT_ID=BAA-xxxxxxxxxxxxxxxxxxxx
PAYPAL_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx
PAYPAL_MODE=live            # 'live' (cobros reales) | 'sandbox'
```

O bien, en `functions/credenciales.local.json` (copiá
`credenciales.local.ejemplo.json`):

```json
{
  "PAYPAL_CLIENT_ID": "BAA-xxxxxxxxxxxxxxxxxxxx",
  "PAYPAL_CLIENT_SECRET": "xxxxxxxxxxxxxxxxxxxxxxxx",
  "RAPID_ACCESS_KEY": "rak_xxxxxxxxxxxx",
  "RAPID_SECRET_KEY": "rsk_xxxxxxxxxxxx"
}
```

> ✅ **Estado actual:** credenciales de **PRODUCCIÓN (live)** puestas y
> `PAYPAL_MODE = 'live'`. Verificado contra la API de PayPal (OAuth `200 OK` y
> creación de orden `201 CREATED` en `api-m.paypal.com`).
> ⚠️ En **live** PayPal exige **HTTPS** (ver sección 4). Ahora **los cobros son
> reales**: prueba con cuidado. Para volver a pruebas, cambia a `'sandbox'` y usa
> las credenciales de sandbox.

- `live` → cobros reales (API `https://api-m.paypal.com`).
- `sandbox` → pruebas (API `https://api-m.sandbox.paypal.com`).

> También puedes dejar el código intacto y definir las variables de entorno
> `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET` y `PAYPAL_MODE` en el servicio del
> VPS (recomendado para no guardar el secreto en el código).

> Nota: la integración usa el `fetch` global de Node.js, por lo que requiere
> **Node 18 o superior** (el proyecto declara Node 24 en `functions/package.json`).

Opcional: si tu dominio/puerto público cambia, ajusta la URL base:

```js
const PAYPAL_VPS = process.env.PAYPAL_VPS_URL || 'http://5.161.88.42:3000';
```

---

## 2. Endpoints nuevos (todos en el mismo servidor, puerto 3000)

| Método | Ruta | Para qué |
|---|---|---|
| `POST` | `/paypal/crear-orden` | Requiere `Authorization: Bearer <idToken Firebase>`. Devuelve `{ initPoint }` = URL de **tu página de checkout**. |
| `GET` | `/paypal/checkout?s=...` | Página con los **botones de PayPal + opción de tarjeta**. Se abre en el WebView de la app. |
| `POST` | `/paypal/orden-js?s=...` | Crea la orden de PayPal (la usa la página internamente). |
| `POST` | `/paypal/capturar?s=...` | Captura la orden y activa la membresía. |
| `GET` | `/paypal/retorno` | (Respaldo) PayPal redirige aquí al aprobar. |
| `GET` | `/paypal/cancelado` | El usuario canceló → `starkgo://pago/fallido`. |
| `POST` | `/paypal/webhook` | Confirmación asíncrona (respaldo). Procesa `PAYMENT.CAPTURE.COMPLETED`. |

La página de checkout usa un **token firmado (HMAC)** con `uid + planId + expiración`
(30 min), así se crean/capturan órdenes sin exponer el token de Firebase.


La membresía se activa con el mismo criterio que Mercado Pago: toma
`fechaVencimiento` (si aún está vigente) y le suma los meses del plan, y guarda
`planMembresia`, `activo: true` y el mapa `plan { tipo, nombre, meses, precio }`.

**Idempotencia:** cada captura se registra en la colección `paypal_ordenes/{captureId}`.
Así, aunque PayPal llame al retorno **y** al webhook, la membresía se activa una
sola vez.

---

## 2.1. Pagar con tarjeta sin iniciar sesión y con colores propios

La app **ya no abre la página de PayPal**. Abre **tu propia página**
`/paypal/checkout`, donde se pintan los **campos de la tarjeta dentro de tu
página** usando **PayPal Card Fields (ACDC)**, con **colores definidos por
nosotros** (texto oscuro sobre fondo blanco) para que todo sea legible.

- Si la cuenta tiene **ACDC habilitado** → se muestran los campos
  **Número / Vencimiento / CVC** + botón "Pagar ahora", y debajo el botón de PayPal.
- Si **no** está habilitado → se muestra solo el botón normal de PayPal (respaldo).

> **Requisito para los campos embebidos:** la cuenta de PayPal debe tener activado
> **"Advanced Credit and Debit Card Payments" (ACDC)**.
> - En **sandbox** normalmente ya viene disponible.
> - En **live** hay que solicitarlo a PayPal (requiere cuenta **Business**).

Los estilos se controlan desde `estiloCampos` (en `functions/index.js`, dentro del
bloque PayPal) por si quieres cambiar colores o tipografía.

Al terminar el pago, la página redirige a `starkgo://pago/exitoso` y la app
muestra la pantalla de éxito (misma lógica que ya existía).


---

## 3. Configurar el Webhook en PayPal

1. Entra a tu app en <https://developer.paypal.com> → **Webhooks**.
2. Agrega la URL:
   ```
   http://5.161.88.42:3000/paypal/webhook
   ```
3. Suscribe el evento **`PAYMENT.CAPTURE.COMPLETED`**.

---

## 4. ⚠️ Importante sobre HTTPS

PayPal exige que `return_url` / `cancel_url` sean URLs **HTTPS** en producción
(live). Este VPS responde por `http://` en el puerto 3000.

Si PayPal rechaza el `return_url` en modo **live**, tienes dos opciones:

1. **Recomendado:** poner HTTPS delante del puerto 3000 con un dominio
   (por ejemplo Nginx/Caddy + Let's Encrypt) y luego ajustar:
   ```js
   const PAYPAL_VPS = process.env.PAYPAL_VPS_URL || 'https://tu-dominio.com';
   ```
2. Mientras pruebas, usa `PAYPAL_MODE = 'sandbox'`, que sí admite `http`.

> El WebView de la app sigue funcionando igual: al terminar, PayPal llama a
> `/paypal/retorno`, el VPS responde `302` hacia `starkgo://pago/exitoso` y el
> WebView lo intercepta (misma lógica que ya usa Mercado Pago).

---

## 5. Cómo se ve en la app

En la pantalla **Renovar Membresía** ahora hay un selector **Método de pago**:

- **PayPal** (por defecto) → `POST /paypal/crear-orden`
- **Mercado Pago** → `POST /mp/crear-preferencia` (sin cambios)

Ambos abren la misma pantalla `PagoWebViewPage`, que detecta el retorno a
`starkgo://pago/exitoso | fallido | pendiente`.

---

## 6. Verificación rápida

1. Reinicia el servidor Node.js y revisa en el log:
   ```
   [PP] PayPal cargado (modo=live)
   ```
2. En la app elige un plan → selecciona **PayPal** → **Pagar**.
3. Completa el pago en el WebView.
4. Verifica en Firestore que `user/{uid}` quedó con:
   ```json
   {
     "planMembresia": "1m",
     "activo": true,
     "fechaVencimiento": "...",
     "plan": { "tipo": "completo", "nombre": "1 Mes StarkGo", "meses": 1, "precio": 15 }
   }
   ```
5. En el log del VPS verás:
   ```
   [PP] Orden creada uid=... plan=1m order=...
   [PP] Retorno orden=... status=COMPLETED
   [PP] ✅ uid=... renovado hasta ... plan=1m tipo=completo
   ```
