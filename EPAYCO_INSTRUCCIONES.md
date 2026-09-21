# 💳 Módulo ePayco — pagos con tarjeta, PSE y efectivo

Este documento explica cómo dejar funcionando la pasarela **ePayco** en la
app (botón *Pagar con ePayco*) y en el VPS, y qué revisar si algo falla.

> ✅ ePayco quedó integrado **igual que Rapid**: el botón se muestra SOLO
> cuando el VPS informa que está en **producción**
> (`config_pagos/epayco.produccion = true`). Mientras no cargues las llaves,
> el botón queda **oculto** y no molesta a nadie.
>
> 🇨🇴 **ePayco también se muestra en Colombia** (además de Mercado Pago), así
> que podés probarla desde tu propio celular sin cambiar nada más.

---

## 🚀 Prueba rápida (2 minutos, en Colombia)

1. Subí `functions/index.js` al VPS **y reiniciá el servicio** (`pm2 restart starkgo-api`).
2. En Firestore, documento **`config_pagos/epayco`**:
   **publicKey** y **privateKey** son las que hacen funcionar el checkout (las otras
   dos quedan para validar la firma del webhook), más:

```json
{
  "produccion": true,
  "modo": "test",
  "excluirPaises": [],
  "paises": []
}
```

3. Esperá ~15 segundos (el VPS relee la config) y abrí la app → en la pantalla
   de membresía vas a ver **Mercado Pago y ePayco**.
4. Pagá con una **tarjeta de pruebas** de ePayco. `modo: "test"` significa que
   **no se cobra de verdad**.
5. Verificá en los logs del VPS: `[EPAYCO] Confirmación ... firma=OK` y
   `[ePayco] ✅ uid=... renovado hasta ...`.
6. ⚠️ Cuando termines la prueba, poné `"produccion": false` (o `modo: "live"`
   con las llaves de producción). Mientras el botón esté visible y en `test`,
   cualquiera con una tarjeta de prueba podría activar la membresía.

---

## 1. Qué se tocó

| Parte | Archivo | Qué hace |
|---|---|---|
| App · servicio | `stark_go/lib/services/precios_service.dart` | Lee `pasarelas.epayco` del VPS/espejo → `epaycoProduccion` |
| App · pantalla activar | `stark_go/lib/pages/activar_membresia/activar_membresia_widget.dart` | Botón ePayco + endpoint `/epayco/crear-orden` |
| App · pantalla renovar | `stark_go/lib/pages/renovar_membresia/renovar_membresia_widget.dart` | Igual que la anterior |
| VPS | `functions/index.js` | Módulo completo `/epayco/*` |

El WebView (`stark_go/lib/pages/Pago/pago_webview_page.dart`) **no necesitó
cambios**: ePayco devuelve el navegador a `/epayco/respuesta` y el VPS
redirige a `starkgo://pago/exitoso | pendiente | fallido`, deep links que ya
existían.

---

## 2. Llaves que necesitás (panel de ePayco)

Entrá a tu panel de ePayco → **Integraciones → Llaves de API** y copiá:

| Dato del panel | Variable | ¿Obligatoria? |
|---|---|---|
| `public_key` | `EPAYCO_PUBLIC_KEY` | **SÍ — es la que crea el checkout** |
| `private_key` | `EPAYCO_PRIVATE_KEY` | **SÍ — la usa el login del API** |
| `p_cust_id_cliente` (N° de cliente) | `EPAYCO_CUST_ID_CLIENTE` | Opcional (valida la firma del webhook) |
| `p_key` | `EPAYCO_P_KEY` | Opcional (valida la firma del webhook) |
| Modo de cobro | `EPAYCO_MODE` | `test` \| `live` |

> ⚠️ **Cambio importante (20/09/2026):** el *checkout clásico* por URL
> (`p_cust_id_cliente` + `p_key` + `x_signature`) **ya no existe**. La página
> del checkout es una SPA que sólo entiende `sessionId`; con la URL vieja el
> cliente veía una **página 404**. Ahora el VPS crea una **sesión por API** y
> abre `https://secure.epayco.co/checkout.php?sessionId=<id>`.
> Por eso ahora las llaves que hacen falta son **public_key + private_key**.

**Estado actual:** las llaves de **SANDBOX** ya quedaron cargadas en
`functions/credenciales.local.json` (junto a las de Rapid y PayPal, que no se
tocaron). Si preferís cambiar la clave del checkout, se cambia desde Firestore
(ver punto 3) **sin tocar el código ni la app**.

---

## 2.b ✅ Ya tenés ePayco de PRODUCCIÓN — ¿qué cambio en Firebase?

> **Las llaves son las MISMAS en pruebas y en producción** (`public_key`,
> `private_key`, `p_cust_id_cliente` y `p_key`): la cuenta es una sola.
> Lo único que decide si el cobro es real es la bandera **`test`**, y acá la
> manda el campo **`modo`** de `config_pagos/epayco`:
> `"test"` → `x_test_request=true` (no se cobra) · `"live"` → cobro real.
>
> 👉 Entonces **en Firebase NO se cambia ninguna llave**: sólo `produccion` y `modo`.

### Caso A · Ensayar sin cobrar (hacé este primero)

Firestore → **`config_pagos/epayco`**:

```json
{
  "produccion": true,
  "modo": "test",
  "moneda": "COP",
  "montoMax": 0,
  "firmaObligatoria": false,
  "paises": [],
  "excluirPaises": [],
  "forzar": true
}
```

- `produccion: true` → el botón **se ve** en la app (también en Colombia).
- `modo: "test"` → se paga con **tarjeta de pruebas** y **no se cobra**.
- `montoMax: 0` → **sin tope**: hoy la cuenta acepta hasta **5.000.000 COP**
  (ver el tope real medido en el punto 3.b), así que también pasan 6 Meses y 1 Año.
- `forzar: true` → se muestra en todo el mundo mientras ensayás (después ponelo
  en `false` y usá `excluirPaises` si querés).

### Caso B · Probar el cobro REAL (producción de verdad)

```json
{
  "produccion": true,
  "modo": "live",
  "moneda": "COP",
  "montoMax": 0,
  "firmaObligatoria": true
}
```

- `modo: "live"` → **cobro real** con tarjeta real.
- `montoMax: 0` → sin tope (o el tope real de tu cuenta, si ya lo conocés).
- Probá con el plan más barato (**Voucher 1 Mes, USD 3**) para no arriesgar plata.
- ⚠️ Si dejás `produccion: true` + `modo: "test"`, **cualquiera con una tarjeta
  de pruebas puede activar la membresía**: usá el Caso A sólo mientras ensayás
  y volvé a `"produccion": false` al terminar.

### Caso C · Cobrar en USD (producción real en dólares)

En `config_pagos/epayco` **lo único distinto es `moneda`** (el resto igual que
el Caso B):

```json
{
  "produccion": true,
  "modo": "live",
  "moneda": "USD",
  "montoMax": 0,
  "paises": [],
  "excluirPaises": [],
  "forzar": false,
  "firmaObligatoria": true
}
```

- `moneda: "USD"` → el cliente paga **el precio exacto del plan en dólares**
  (15 / 39 / 69 / 120 · vouchers 3 / 8 / 15 / 30) y **ePayco hace la conversión**
  con su propia tasa (~la TRM del día). La app sigue mostrando el equivalente en
  COP con la tasa del VPS, pero eso es sólo referencia: **el cargo es en USD**.
- `montoMax: 0` → **sin tope**: con el rango verificado (5.000–5.000.000 COP)
  los 8 planes entran, incluido 1 Año (USD 120 ≈ 383.100 COP). Si algún día
  ePayco te confirma un tope menor, poné ese número **en USD** (ej: `62`) y la
  app esconderá sólo los planes que lo superen.
- `forzar: false` + `excluirPaises: []` → se muestra en todos los países
  (incluida Colombia, donde además está Mercado Pago).
- ✅ Con el `index.js` actual, el VPS convierte el tope a COP para la app
  (`epaycoMontoMaxCop()`): si ponés `montoMax: 62`, la app **no** esconde todos
  los botones, sólo avisa en los planes que superan el tope. El cobro real se
  sigue validando en **USD** en `/epayco/crear-orden`.
- ⚠️ Confirmá con ePayco que tu cuenta **está habilitada para cobrar en USD**.
- 🔎 Después de cargarlo: `/epayco/diag` debe mostrar `moneda: "USD"` y el
  `montoMax` en USD; en `config_publica/pasarelas` el `montoMax` que ve la app
  aparece **ya convertido a COP**.

### Qué NO hay que tocar

| Cosa | ¿Hace falta? |
|---|---|
| `publicKey` / `privateKey` | **No** (son las mismas). Si las pegás igual en el documento, **mandan sobre** `functions/credenciales.local.json` |
| `custIdCliente` / `pKey` | **No** (mismas; sólo se usan para validar la firma del webhook) |
| Reiniciar el VPS | **No para cambiar config**: relee `config_pagos/epayco` cada ~15 s. Sí hay que **subir `index.js` y `pm2 restart starkgo-api`** una vez si vas a cobrar en **USD** con `montoMax` (ese `index.js` incluye la conversión del tope a COP para la app) |
| Variables de entorno del VPS | No, salvo que quieras (`EPAYCO_MODE=live`): el `modo` de Firestore **siempre gana** |
| Reglas de Firestore | Mantené `config_pagos` cerrado: `match /config_pagos/{doc} { allow read, write: if false; }` |

### Verificación en 3 pasos

1. `http://5.161.88.42:3000/epayco/diag?refrescar=1` → revisá `produccion`, `modo`,
   `moneda`, `apiOk` (llaves aceptadas por el API), `publicKey`/`privateKey`,
   `montoMax` (en tu moneda) y **`montoMaxAppCop`** (el tope ya convertido a COP,
   que es el que compara la app), y **`urlCheckoutPrueba`** (abrí esa URL en el
   celular y pagás ahí mismo).
2. En modo `test`: `http://5.161.88.42:3000/epayco/test-orden?planId=v1m` →
   devuelve `urlCheckout`.
3. Después de pagar: `http://5.161.88.42:3000/epayco/estado?factura=SG-…` y los
   logs del VPS (`[EPAYCO] Confirmación … firma=OK` + `✅ uid=… renovado hasta …`).
   Cuando veas `firma=OK` en un cobro real, dejá `"firmaObligatoria": true`.

> ⚠️ **Ojo con `moneda: "USD"`:** el `montoMax` viaja **en USD** (su moneda), pero
> la app lo compara contra el precio del plan en **COP**
> (`PreciosService.epaycoPermiteMonto(precioCop)`). Por eso, con un `index.js`
> **viejo** en el VPS, un `montoMax: 62` escondía el botón en **TODOS** los planes.
> Desde el `index.js` actual el VPS publica el tope **ya convertido a COP**
> (`epaycoMontoMaxCop()`; lo podés ver en `/epayco/diag` como `montoMaxAppCop`),
> así que `montoMax: 62` (USD) sólo deja fuera **6 Meses** y **1 Año**. Si todavía
> no subiste ese `index.js`, usá `"montoMax": 0`.

---

## 3. Dónde cargar las llaves (3 opciones, en este orden de prioridad)

**A) Firestore — RECOMENDADO** (no hay que reiniciar el VPS ni tocar la app)
Documento: `config_pagos/epayco`

```json
{
  "produccion": true,
  "modo": "live",
  "custIdCliente": "1593290",
  "pKey": "TU_P_KEY_DE_PRODUCCION",
  "publicKey": "TU_PUBLIC_KEY",
  "privateKey": "TU_PRIVATE_KEY",
  "moneda": "COP",
  "pais": "CO",
  "paises": [],
  "excluirPaises": [],
  "forzar": false,
  "montoMax": 200000,
  "firmaObligatoria": false,
  "checkoutUrl": "https://secure.epayco.co/checkout.php"
}
```

| Campo | Para qué sirve |
|---|---|
| `produccion` | `false` = botón **oculto** en la app · `true` = **visible** |
| `modo` | `test` cobra en pruebas (`x_test_request=true`) · `live` cobra de verdad |
| `custIdCliente` / `pKey` | llaves del checkout (podés pegar las de producción acá) |
| `publicKey` / `privateKey` | llaves del API (opcionales) |
| `paises` | lista BLANCA de países. Vacía = todos |
| `excluirPaises` | lista NEGRA. Vacía = **ninguno excluido** (se ve en Colombia también). Poné `["CO"]` si querés ocultarlo en Colombia |
| `moneda` | **`USD`** (recomendado si vendés a varios países: el cliente paga en dólares, sin conversión) o `COP` (ePayco convierte internamente con su tasa del día) |
| `forzar` | `true` = mostrar ePayco en todo el mundo (para probar) |
| `montoMax` | **Tope del monto, en la MISMA moneda de `moneda`**. Opcional: `0` = sin tope. Sirve para que la app **oculte el botón** y explique el motivo en los planes que superan el tope, en vez de mostrar el error técnico de ePayco. Hoy la cuenta acepta **5.000–5.000.000 COP** (medido el 21/09/2026), así que `0` deja entrar los 8 planes. El VPS lo manda a la app **ya convertido a COP** con la tasa del día (la app compara el tope contra el precio en COP) |
| `firmaObligatoria` | `true` = rechazar transacciones con firma que no coincida (ver punto 8) |

**B) Variables de entorno del VPS** (`.env` o `export`):

```
EPAYCO_CUST_ID_CLIENTE=1593290
EPAYCO_P_KEY=TU_P_KEY
EPAYCO_PUBLIC_KEY=TU_PUBLIC_KEY
EPAYCO_PRIVATE_KEY=TU_PRIVATE_KEY
EPAYCO_MODE=test          # test | live
EPAYCO_PRODUCCION=false   # true = mostrar el botón
EPAYCO_PAISES=            # lista blanca (vacío = todos)
EPAYCO_EXCLUIR_PAISES=CO  # en Colombia no se muestra
```

**C) `functions/credenciales.local.json`** (el mismo archivo de Rapid/PayPal):
ya tiene las llaves de sandbox (`EPAYCO_PUBLIC_KEY`, `EPAYCO_PRIVATE_KEY`,
`EPAYCO_CUST_ID_CLIENTE`, `EPAYCO_P_KEY`, `EPAYCO_MODE=test`).

> 🔥 **Regla de Firestore:** `config_pagos` guarda llaves secretas, dejalo
> sin acceso para los clientes:
> `match /config_pagos/{doc} { allow read, write: if false; }`

---

## 3.b Cobrar en USD o en COP

En `config_pagos/epayco` el campo **`moneda`** decide en qué moneda se cobra
(el VPS lo relee cada 15 s: **no hay que reiniciar nada**):

| `moneda` | Qué se le cobra al cliente | Cuándo conviene |
|---|---|---|
| **`USD`** | El **precio exacto del plan en dólares** (USD 15, USD 39…) — ePayco lo convierte internamente a COP con su tasa | Vendés a varios países y querés mostrarlo en dólares (sin depender de la tasa del día) |
| `COP` | El equivalente en pesos con **la tasa del día** (la misma que ve el cliente en la app) | Solo clientes colombianos |

**Probado contra ePayco (20/09/2026):** la API y el checkout **aceptan USD**
(`currency: 'USD'`, `amount: 15`) y ePayco hace la conversión con su propia
tasa (~3.192,9 COP/USD, igual a la TRM del día).

⚠️ **Ojo con el tope del monto:** ePayco valida el monto de la transacción y, si
no entra, responde
`[VALIDATION_ERROR] property Amount(...) must be between <min> and <max>`.

**Medición real (21/09/2026, llaves de sandbox del repo):** el rango que acepta
la cuenta hoy es **5.000 – 5.000.000 COP**, y se probaron los montos uno por uno
contra `POST /payment/session/create`:

| Monto pedido | Resultado |
|---|---|
| 3.000 COP | ❌ `must be between 5000 and 5000000` (menor al mínimo) |
| 5.000 COP | ✅ `sessionId` |
| 200.000 COP | ✅ `sessionId` |
| 220.300 COP (6 Meses ≈ USD 69) | ✅ `sessionId` |
| **383.100 COP (1 Año ≈ USD 120)** | ✅ **`sessionId`** |

O sea: **hoy los 8 planes entran**, incluidos 6 Meses y 1 Año (el
`must be between 5000 and 200000` que se anotó el 20/09 ya **no** aplica: ePayco
subió el tope de la cuenta). Para comprobar el tope de TU cuenta (sandbox o
LIVE, con las llaves que estén cargadas) usá el diagnóstico con el plan:

```
http://5.161.88.42:3000/epayco/diag?planId=1a&refrescar=1   → montoAceptado / limiteEpayco
http://5.161.88.42:3000/epayco/diag?monto=383100&refrescar=1
```

👉 Igual conviene **confirmar con ePayco** si tu cuenta está habilitada para
cobrar en **USD** (la conversión la hace ePayco con su tasa). Mientras no haya
un tope conocido, dejá `"montoMax": 0`; si algún día ePayco te confirma uno
menor, poné ese número **en USD**: el VPS lo convierte a COP para la app y sigue
validando en USD en `/epayco/crear-orden`.

1. Cargá las llaves (paso 3).
2. En `config_pagos/epayco` poné `"produccion": true` (y `"modo"` según lo que
   quieras: `test` para ensayar, `live` para cobrar de verdad).
3. Listo: **sin reinstalar ni recompilar nada**, el VPS publica el cambio en
   `config_publica/pasarelas` y la app muestra/oculta el botón en segundos.

| `produccion` | `modo` | Qué pasa |
|---|---|---|
| `false` | cualquiera | Botón **OCULTO** en la app (pero `/epayco/crear-orden` sigue funcionando para pruebas) |
| `true` | `test` | Botón **VISIBLE** cobrando en PRUEBAS (`x_test_request=true`) |
| `true` | `live` | Botón **VISIBLE** con **cobros reales** (`x_test_request=false`) |

**¿En qué países aparece?** ePayco se muestra por defecto en **todos los
países, incluida Colombia** (donde además está Mercado Pago). Se controla con
dos listas en `config_pagos/epayco`:

- `excluirPaises: []` → no se excluye ninguno (valor por defecto: se ve en
  Colombia y en el resto del mundo).
- `excluirPaises: ["CO"]` → si algún día querés que en Colombia SOLO aparezca
  Mercado Pago.
- `paises: []` → además, si querés limitarlo a ciertos países, poné por
  ejemplo `paises: ["CO","US","MX","PE"]`.
- `forzar: true` → se muestra en **todo el mundo** sin importar las listas.

> 📌 ePayco está pensada para el **resto del mundo** (Mercado Pago solo cobra
> en Colombia) y en Colombia queda como respaldo/para pruebas.

---

## 5. Probar sin esperar a un cliente

**a) Diagnóstico (1 segundo):** abrí en el navegador

```
http://5.161.88.42:3000/epayco/diag
```

Devuelve: si están las llaves, `apiOk` (si ePayco aceptó el **login** con
public/private key), un **`sessionId` real** y `urlCheckoutPrueba` — pegá esa
URL en el navegador del celular y **ya podés pagar de verdad en modo prueba**.

Podés pedirle que pruebe **otro monto** (así medís el tope real de tu cuenta,
también con las llaves de LIVE):

```
/epayco/diag?planId=1a&refrescar=1      → prueba el monto del plan 1 Año
/epayco/diag?monto=383100&refrescar=1   → prueba ese monto exacto (en cfg.moneda)
```

Campos útiles de la respuesta: `planProbado`, `montoProbado`, `monedaProbada`,
**`montoAceptado`** (true = tu cuenta acepta ese monto) y **`limiteEpayco`**
(`{min, max}` en COP) cuando ePayco lo rechaza; `montoMax` (en tu moneda) y
`montoMaxAppCop` (el tope, ya convertido a COP, que compara la app).

Si `apiOk` es `false`, mirá `apiError`: ahí está el motivo exacto.

**b) Probar desde la app:** con `produccion: true` y `modo: "test"` el botón
se ve (también en Colombia), y `modo=test` significa que **no se cobra de
verdad**. Pagá con una **tarjeta de pruebas** de ePayco y listo.
Si por algún motivo no lo ves, agregá `"forzar": true` y esperá ~15 segundos.

La orden queda registrada en `epayco_ordenes/<factura>` y la podés consultar:

```
http://5.161.88.42:3000/epayco/estado?factura=SG-XXXXXX-YYYY
```

Ahí ves `estado` (PAGADO / PENDIENTE / RECHAZADO), `codResponse`, la
franquicia, el monto y si quedó `activado`.

**c) Ver los logs del VPS:** cada paso imprime líneas con `[EPAYCO]`
(orden creada, firma OK/NO COINCIDE, activación).

> ✅ Verificado: el checkout de ePayco se abre por **GET** con los datos en la
> URL (el POST al mismo endpoint responde **405**), así que la URL que arma el
> VPS es la correcta para el WebView.

---

## 6. Cómo funciona (flujo completo)

```
App                       VPS (5.161.88.42:3000)              ePayco
 │  POST /epayco/crear-orden  │                                  │
 │───────────────────────────►│ 1) POST /login (Basic pub:priv)  │
 │                             │─────────────────────────────────►│
 │                             │ 2) POST /payment/session/create  │
 │                             │◄───────── { sessionId } ─────────│
 │      { initPoint }          │ guarda la orden (epayco_ordenes) │
 │◄───────────────────────────│                                  │
 │  WebView → /epayco/checkout?sessionId=…  (página NUESTRA)      │
 │     └ carga checkout.js → checkout-v2.js → configure().open() ─►│ el cliente paga
 │                             │  POST /epayco/confirmacion ◄─────│ (server-to-server)
 │                             │  activa la membresía             │
 │                             │  GET /epayco/respuesta?ref_payco=◄│ (vuelve el navegador)
 │◄── starkgo://pago/… ────────│                                  │
```

> 🔎 **¿Por qué la página intermedia?** El checkout **V2** de ePayco (el que
> usan las sesiones) **no se abre por URL**: hay que cargar su JS
> (`https://checkout.epayco.co/checkout.js`, que a su vez carga
> `checkout-v2.js`) y llamar `ePayco.checkout.configure({sessionId}).open()`.
> La URL clásica `secure.epayco.co/checkout.php?sessionId=…` pertenece al
> checkout **V1** → con una sesión V2 mostraba *"404 page not found"*.
>
> ⚠️ **Y hay que pasarle los datos del plan**, no sólo el `sessionId`: si no,
> el checkout muestra **$0.00**. Por eso nuestra página
> `/epayco/checkout?factura=SG-…` lee la orden de Firestore y le manda
> `amount`, `description`, `invoice`, `currency`, etc. (así el monto no se
> puede alterar desde la URL).
>
> 🧭 **Nuestra cuenta es V1** (lo dice ePayco en
> `…/commerce/v2/check?publicKey=…` → `{"isV2": false}`), así que el flujo que
> usamos es el **clásico por JS**: `configure({key, test}).open(datos)`. Ese
> flujo **crea la transacción** y la muestra en un iframe de `secure.epayco.co`.

- **Idempotente:** la activación usa `epayco_ordenes/pago_<x_ref_payco>`; si
  ePayco notifica dos veces, la membresía **no se extiende dos veces**.
- **Datos de auditoría:** en `epayco_ordenes/<factura>` quedan el monto, la
  moneda, el estado (`codResponse`), la franquicia, el e-mail y el origen
  (`respuesta` / `confirmacion`).
- **Monto:** siempre en COP, con la **tasa del día** del VPS (la misma que ve
  el cliente en la app). No se cobra un peso distinto al que se muestra.

---

## 6.b ⚠️ «El pago se acreditó pero la app quedó en *Pago pendiente*»

**Síntoma:** el cliente paga, ePayco cobra (lo ves en su panel) y la app se
queda en la pantalla de **pago pendiente**; al tocar **“Verificar estado”** no
pasa nada (sigue en pendiente).

**Causa (encontrada el 21/09/2026):** esa pantalla pedía **siempre**
`POST /rapid/verificar`. Si el pago se hizo con **ePayco**, el VPS nunca lo
miraba → “Verificar estado” era inútil para ePayco. Además, si la vuelta del
navegador traía sólo `?ref_payco=` (sin `x_cod_response`) y el webhook de
confirmación no había llegado, la orden quedaba sin estado y la app no tenía
forma de enterarse.

**Qué se arregló (todo en el VPS, no hace falta reinstalar la app):**

| Arreglo | Dónde |
|---|---|
| “Verificar estado” ahora revisa **las 3 pasarelas**: Rapid, **ePayco** y **Mercado Pago** | `/rapid/verificar` (es el endpoint que ya llamaba el APK) |
| Endpoints propios por pasarela | `POST /epayco/verificar` y `POST /mp/verificar` |
| **Consulta el estado REAL a ePayco** al verificar (`GET /transaction/detail?refPayco=`) → ya no depende de que llegue el webhook | `epaycoConsultarEstado()` |
| **Consulta los pagos a Mercado Pago** (`GET /v1/payments/search?external_reference=uid\|planId`) y activa los aprobados | `mpVerificarPagos()` |
| La vuelta del checkout también consulta a ePayco si no trae el código de respuesta (antes quedaba en “pendiente” hasta que llegara el webhook) | `/epayco/respuesta` |
| Recuperar un pago trabado (soporte) | `GET /epayco/reparar` |
| 🐞 **Mercado Pago ya no duplica meses**: antes el webhook extendía la membresía en **cada** notificación y podía sumar meses de más. Ahora usa la misma puerta idempotente (`pago_<pagoId>`) que las otras pasarelas | `/mp/webhook` |
| Se guarda la orden de MP (`mp_ordenes/<preferenceId>`) para saber qué compra quedó esperando ese usuario | `/mp/crear-preferencia` |
| Caché de 20 s en las consultas a las pasarelas (la app pregunta cada pocos segundos durante el auto-chequeo) | `conCache()` |

**Cómo destrabar un pago que ya está cobrado (ya mismo):**

```
# 1) Ver qué pasó con las órdenes (todas o las de un cliente)
http://5.161.88.42:3000/epayco/ordenes?apikey=starkgo_admin_2025&limite=20
http://5.161.88.42:3000/epayco/ordenes?apikey=starkgo_admin_2025&uid=UID_DEL_CLIENTE

# 2) Ver una factura concreta
http://5.161.88.42:3000/epayco/estado?factura=SG-XXXXXX-YYYY

# 3) Activarla (le extiende la membresía al cliente; idempotente)
http://5.161.88.42:3000/epayco/reparar?apikey=starkgo_admin_2025&factura=SG-XXXXXX-YYYY
http://5.161.88.42:3000/epayco/reparar?apikey=starkgo_admin_2025&uid=UID_DEL_CLIENTE
```

Luego le decís al cliente que abra la app (o que toque **“Verificar estado”**):
si la membresía ya se activó, la app la muestra. Si el reporte dice
`estado: (todavía sin estado)`, ePayco no confirmó ese cobro: revisá el pago en
su panel y que la **URL de confirmación** apunte a `/epayco/confirmacion`.

**¿Hace falta app nueva?** No para destrabar (el arreglo va en el VPS). Igual, la
próxima compilación lleva tres mejoras:

- `PagoWebViewPage` recibe `metodo` (pasarela) y `ordenId` (factura).
- “Verificar estado” llama primero al endpoint de **esa** pasarela
  (`/epayco/verificar`, `/mp/verificar` o `/rapid/verificar`) y, si no encuentra
  nada, al de respaldo.
- 🔄 **Auto-chequeo**: mientras la pantalla de **pago pendiente** está abierta,
  la app revisa sola cada **12 s** (hasta 20 intentos ≈ 4 min) y el texto
  “Revisando el pago automáticamente… (n/20)” muestra el avance. **Si el pago se
  acredita, pasa a la pantalla de éxito sin que el cliente toque nada** (el botón
  “Verificar estado” sigue disponible, y después de los 20 intentos el
  auto-chequeo se detiene y queda sólo el botón).

---

## 7. Endpoints del VPS

| Método | Ruta | Para qué |
|---|---|---|
| POST | `/epayco/crear-orden` | La app pide el checkout (requiere token de Firebase) |
| GET | `/epayco/checkout?factura=SG-…` | **Página que abre el WebView**: lee la orden y lanza el checkout V2 de ePayco por JS (con monto incluido) |
| GET | `/epayco/respuesta` | Vuelve el navegador del cliente → consulta el estado real en ePayco y regresa a la app |
| POST | `/epayco/confirmacion` | Webhook de ePayco (respaldo, sin sesión) |
| POST | `/epayco/verificar` | Lo usa el botón **“Verificar estado”**: activa los cobros de ePayco ya aprobados (requiere token) |
| GET | `/epayco/reparar?apikey=…&factura=SG-…` | **Soporte**: activa un pago que quedó pendiente (o `&uid=…` para todas sus órdenes) |
| GET | `/epayco/ordenes?apikey=…&limite=20` | **Soporte**: últimas órdenes con estado, ref, monto y si quedaron activadas |
| GET | `/epayco/diag` | Diagnóstico + sesión de prueba real. Con `?planId=1a` o `?monto=383100` prueba ese monto (así medís el tope real de la cuenta) |
| GET | `/epayco/test-orden?planId=1m` | Prueba el pago completo sin celular (sólo en modo test) |
| GET | `/epayco/estado?factura=SG-…` | Consultar una orden (soporte) |
| POST | `/mp/verificar` | Lo usa el botón **“Verificar estado”** para Mercado Pago: busca los pagos **aprobados** del usuario y activa la membresía (requiere token) |
| POST | `/rapid/verificar` | **Endpoint “comodín”**: el APK instalado llama acá siempre, así que revisa **Rapid + ePayco + Mercado Pago** (y también sirve para el auto-chequeo) |

En el panel de ePayco (Configuración → URLs) podés registrar:

```
URL de respuesta:     http://5.161.88.42:3000/epayco/respuesta
URL de confirmación:  http://5.161.88.42:3000/epayco/confirmacion
```

(Las dos viajan en cada transacción, así que no son obligatorias, pero
registrarlas es lo recomendado.)

---

## 8. Firma y seguridad

| Firma | Fórmula (MD5, en minúsculas) | Dónde se usa |
|---|---|---|
| Respuesta/confirmación | `md5(p_cust_id_cliente ^ p_key ^ x_ref_payco ^ x_transaction_id ^ x_amount ^ x_currency_code)` | La manda ePayco y el VPS la compara |

> ✅ **Verificado con las llaves de sandbox (20/09/2026):** ePayco sigue
> mandando esa firma y el VPS la valida (`[EPAYCO] Confirmación … firma=OK`).
> Ya no existe la firma de la *orden* (`x_signature` de la URL clásica) porque
> el checkout ahora es por sesión.

Campo `firmaObligatoria` de `config_pagos/epayco`:

- `false` (por defecto): si la firma no coincide, se **avisa en el log** y la
  orden igual se procesa según `x_cod_response`. Se usa los primeros días
  para no trabar un cobro real por un detalle de firma.
- `true`: si la firma no coincide, la transacción se **descarta** (401 en la
  confirmación y `starkgo://pago/fallido` en la respuesta). Ponelo en `true`
  cuando ya hayas visto `firma=OK` en un pago de prueba.

---

## 9. Problemas típicos

| Síntoma | Causa / solución |
|---|---|
| **El WebView muestra "404 page not found"** | El VPS está abriendo el checkout **por URL** (`secure.epayco.co/checkout.php?sessionId=`), que es el checkout **V1** y no entiende una sesión V2. Hay que **subir el `index.js` nuevo y reiniciar** (`pm2 restart starkgo-api`): ahora `initPoint` apunta a nuestra página `/epayco/checkout?factura=…`, que carga `checkout.js` → `checkout-v2.js` y abre el checkout con `configure({sessionId}).open()` |
| **El checkout muestra $0.00** | La página le está pasando sólo el `sessionId` sin los datos de la orden. Con el `index.js` nuevo la página lee `epayco_ordenes/<factura>` y le manda `amount`, `description`, `invoice`, `currency` → vuelve a mostrar el monto correcto |
| Error `[VALIDATION_ERROR] - property Amount must be between X and Y` | Ese es el rango que acepta **tu cuenta**. Medido el **21/09/2026**: **5.000–5.000.000 COP** (o sea, los 8 planes entran: el `200000` visto el 20/09 ya no aplica). Para verlo con tus llaves actuales: `/epayco/diag?planId=1a&refrescar=1` → mirá `montoAceptado` / `limiteEpayco` |
| El botón no aparece en la app | `config_pagos/epayco.produccion` está en `false`, o el VPS no pudo leer Firestore (mirá los logs `[EPAYCO]`). Abrí `/epayco/diag` |
| Con `moneda: "USD"` desaparece el botón en TODOS los planes | El VPS viejo mandaba `montoMax` crudo (en USD) y la app lo compara contra el precio en **COP** (`epaycoPermiteMonto(precioCop)`). Con el `index.js` actualizado en el VPS el tope se publica **ya convertido a COP** (`epaycoMontoMaxCop()`) y queda arreglado. Mientras tanto: `"montoMax": 0` |
| Un pago de **Mercado Pago** quedó pendiente y “Verificar estado” no hacía nada | Igual que con ePayco: el botón sólo pedía `/rapid/verificar`. Ahora el VPS consulta los pagos aprobados en MP (`/mp/verificar`) desde ese mismo endpoint (ver punto 6.b) |
| La membresía se extendió **más meses** de los comprados con Mercado Pago | Bug corregido: el webhook de MP extendía en cada notificación. Ahora es idempotente (`pago_<pagoId>`). Si ya pasó, ajustá la fecha a mano en Firestore |
| Ya tengo las llaves de PRODUCCIÓN y son las mismas | Es correcto: en ePayco las llaves no cambian entre test y live. Sólo cambiá `config_pagos/epayco` → `produccion` y `modo` (ver punto 2.b) |
| "Error del servidor (503)" al pagar | Faltan `publicKey` / `privateKey`. Cargalas (paso 3) |
| `apiOk: false` en `/epayco/diag` | Las llaves no son válidas para el API (o están mal copiadas). `apiError` dice el motivo exacto |
| `firma=NO COINCIDE` en el log | Las llaves `custIdCliente`/`pKey` del VPS no son de la misma cuenta, o hay espacios al copiarlas |
| El cliente pagó y no se activó | Mirá `epayco_ordenes/<factura>` y `/epayco/estado?factura=…`; con `/epayco/ordenes?apikey=…&uid=…` ves las últimas. Para activarlo: `/epayco/reparar?apikey=…&factura=…` (ver punto 6.b) |
| **El pago se acreditó pero la app quedó en "pendiente" y "Verificar estado" no hacía nada** | Bug encontrado el 21/09: esa pantalla pedía siempre `/rapid/verificar` y para ePayco no miraba nada. Con el `index.js` actual el botón revisa Rapid **y** ePayco, y consulta el estado real a ePayco → se activa al toque (ver punto 6.b) |
| Se activó dos veces | No debería: la llave `pago_<x_ref_payco>` lo evita |
| Al volver del checkout dice "pendiente" | Ahora la vuelta **consulta el estado real a ePayco**: sólo queda en pendiente si ePayco todavía **no aprobó** el cobro (PSE/efectivo tardan). Cuando aprueba, se activa sola o con "Verificar estado" |

---

## 10. Relacionado

| Tema | Documento |
|---|---|
| Mercado Pago solo en Colombia (país del teléfono) | `PASARELAS_POR_PAIS.md` |
| Rapid (tarjeta/PSE) | `VPS_RAPID_PAGOS.md` |
| PayPal | `PAYPAL_INSTRUCCIONES.md` |
| Precios y tasa USD→COP | `PRECIOS_TASA_CAMBIO.md` |
| Planes | `VPS_INSTRUCCIONES.md` |
