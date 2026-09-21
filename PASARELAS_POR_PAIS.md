# 🌎 Pasarelas por país — Mercado Pago en Colombia · ePayco en todos

Regla de negocio actual:

| País del teléfono | Pasarelas que se muestran |
|---|---|
| 🇨🇴 **Colombia** | **Mercado Pago** + **ePayco** |
| 🌍 **Resto del mundo** | **ePayco** |
| — | ~~Rapid~~ **apagada** (se puede volver a encender desde el VPS) |
| — | PayPal desactivado en el código (`_kPayPalHabilitado = false`) |

> 📌 ePayco está pensada para el **resto del mundo** (Mercado Pago solo cobra
> en Colombia), pero **por defecto también se muestra en Colombia** — sirve
> para probar y como respaldo si Mercado Pago falla. Si más adelante querés
> que en Colombia SOLO aparezca Mercado Pago, alcanza con poner
> `excluirPaises: ["CO"]` en `config_pagos/epayco` (sin actualizar la app).

Todo se decide **desde Firestore**, así que podés prender/apagar botones,
cambiar llaves y cambiar los países **sin actualizar la app**.

---

## 1. Cómo se detecta el país

`stark_go/lib/services/pais_service.dart`. Tres señales, en orden (gana la
primera que responde):

| # | Señal | Detalle |
|---|---|---|
| 1 | **Caché del teléfono** | `SharedPreferences` (`sg_pais`), válido 24 h → no golpea la red en cada apertura |
| 2 | **Geolocalización por IP** | `ipwho.is` y, si falla, `ipapi.co` (HTTPS, gratis, sin API key) |
| 3 | **Idioma del teléfono** | `locale` (ej: `es_CO`) — respaldo si no hay internet para el paso 2 |

Decisiones importantes:

- **Si no se puede detectar nada, el botón SÍ se muestra.** Preferimos no
  quitarle el pago a un cliente colombiano por un fallo de red; el VPS
  valida igual contra la cuenta de Mercado Pago al crear la preferencia.
- **No se agregó ningún plugin nuevo**, así que el build (APK/AAB/web) no
  cambia ni hay que reinstalar nada raro.
- Cuando el botón queda oculto, la app muestra un aviso:
  *"Mercado Pago solo está disponible en Colombia. Usa otra pasarela para
  pagar desde tu país."*

---

## 2. Quién decide qué botón se ve

```
VPS /precios  →  pasarelas: {
                   rapid:       { produccion: bool },   → botón Rapid
                   epayco:      { produccion: bool },   → botón ePayco
                   mercadoPago: { paises: ["CO"] }      → botón MP
                 }
                          │
                          ▼
      config_publica/pasarelas (espejo que escribe el VPS)
                          │  (la app lo escucha en TIEMPO REAL)
                          ▼
   PreciosService  +  PaisService (país del teléfono)
                          │
                          ▼
             Botones de pago en la pantalla de membresía
```

| Botón | Condición para mostrarse |
|---|---|
| Mercado Pago | país ∈ `pasarelas.mercadoPago.paises` (por defecto `["CO"]`) y `forzar` = false |
| ePayco | `pasarelas.epayco.produccion` = true **y** el país no está en `excluirPaises` (por defecto vacío = todos) |
| Rapid (PayU) | `RAPID_ACTIVO=true` en el VPS **y** `config_pagos/rapid.produccion` = true |
| PayPal | `_kPayPalHabilitado` (desactivado en el código por ahora) |

Si **ninguna** aplica (ej: cliente en el exterior antes de prender ePayco), la
app muestra un aviso pidiendo que te escriban por WhatsApp para activar el plan
a mano.

---

## 3. Configuración en el VPS / Firestore

**Variables de entorno del VPS:**

| Variable | Por defecto | Para qué |
|---|---|---|
| `MP_PAISES` | `CO` | Países donde se permite Mercado Pago. Ej: `CO,AR` |
| `MP_FORZAR` | `false` | `true` = mostrar Mercado Pago en TODO el mundo (pruebas) |
| `RAPID_ACTIVO` | `false` | `true` = volver a mostrar el botón de Rapid |
| `EPAYCO_PAISES` | vacío (todos) | Lista blanca de ePayco |
| `EPAYCO_EXCLUIR_PAISES` | vacío (ninguno) | Lista negra de ePayco (poné `CO` para ocultarlo en Colombia) |
| `EPAYCO_FORZAR` | `false` | `true` = mostrar ePayco en TODO el mundo (pruebas) |

**Firestore (lo que se puede cambiar en caliente, sin reiniciar nada):**

| Documento | Campos útiles |
|---|---|
| `config_pagos/epayco` | `produccion`, `modo`, `custIdCliente`, `pKey`, `paises`, `excluirPaises`, `forzar` |
| `config_pagos/rapid` | `produccion` (sólo se muestra si `RAPID_ACTIVO=true`) |
| `config_publica/pasarelas` | espejo público (lo escribe el VPS) que la app escucha en TIEMPO REAL |

Rutas:

- `GET /precios` → `pasarelas.mercadoPago`, `pasarelas.epayco`, `pasarelas.rapid`.
- `config_publica/pasarelas` → mismo contenido sin secretos; la app lo escucha
  por Firestore, así que un cambio en `config_pagos/*` **cambia los botones en
  segundos, sin reinstalar la app**.

---

## 4. Probar el filtro

| Prueba | Cómo |
|---|---|
| Estar en Colombia | Con WiFi/datos colombianos el botón **aparece** (log: `[País] CO detectado (IP)`) |
| Simular otro país | `MP_FORZAR=true` en el VPS para ver el botón igual, o cambiar `MP_PAISES` a otro código (ej: `US`) y reiniciar el VPS |
| Ver qué detectó el teléfono | Logs de la app: `[País] <código> detectado (<fuente>)` |
| Borrar la caché del país | Desinstalar/reinstalar la app o borrar datos; el servicio vuelve a detectar |

---

## 5. Si querés cambiar la regla

| Querés… | Cambio (sin tocar la app) |
|---|---|
| Que ePayco deje de verse en Colombia | `config_pagos/epayco` → `excluirPaises: ["CO"]` |
| Que ePayco solo se vea en ciertos países | `config_pagos/epayco` → `paises: ["US","MX","PE"]` |
| Probar ePayco desde un celular colombiano | ya se ve en Colombia; igual podés usar `forzar: true` |
| Permitir MP en más países | `MP_PAISES=CO,AR` en el VPS |
| Que MP nunca se oculte | `MP_FORZAR=true` en el VPS |
| Volver a mostrar Rapid | `RAPID_ACTIVO=true` en el VPS |
| Usar otra señal de país (ej: SIM del teléfono) | `stark_go/lib/services/pais_service.dart` → agregar la señal a `_detectar()` siguiendo el mismo patrón (fallback silencioso) |
| Cambiar el texto de los avisos | `_buildAvisoPais()` y `_buildAvisoSinPago()` en las dos pantallas de membresía |
