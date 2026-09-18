# 💵 Precios y tasa de cambio (USD → COP)

## Por qué antes el precio "subía"

Los planes están en **USD** (lo que ve el cliente en la app) y las pasarelas
colombianas (**Mercado Pago** y **Rapid**) cobran en **COP**.

Antes, el COP de cada plan estaba **escrito a mano** en el catálogo del VPS
(`precioCop: 480000`), calculado con una tasa de **4.000 COP/USD**. Cuando el
dólar bajó a **3.200**, el plan de **US$120** seguía cobrando **$480.000**
(≈ US$150 al cambio real) → de ahí la diferencia.

## Cómo funciona ahora: AUTOMÁTICO 🤖

El VPS **consulta solo la tasa del día** y con ella calcula el COP de todos los
planes. El orden de fuentes (gana la primera que responda con un valor sensato):

| # | Fuente | Detalle |
|---|---|---|
| 1 | **TRM oficial de Colombia** | Superfinanciera vía `datos.gov.co` — el valor oficial del día |
| 2 | `currency-api` | CDN de jsDelivr, sin API key |
| 3 | `open.er-api.com` | Sin API key |
| 4 | `exchangerate-api.com` | Sin API key |
| 5 | **Última tasa guardada** (Firestore) | Si no hay internet: usa la última conocida, nunca queda en cero |

```
COP del plan = precio(USD) × tasa del día   (redondeado a la centena)
```

- **Caché de 6 h**: no consulta en cada venta, solo cuando la tasa “vence”
  (`USD_A_COP_TTL_MIN` para cambiarlo).
- **Se guarda en Firestore** (`config_precios/tasa`) → sobrevive reinicios del VPS.
- La app **lee la tasa y los precios ya calculados** del VPS (`GET /precios`) y
  muestra los dos formatos, así el cliente nunca se lleva la sorpresa:

```
US$120
= $368.700 COP
tasa del día: 3.072,27 COP/USD
```

> ✅ **Se actualiza solo**: si mañana el dólar sube o baja, el precio en COP
> cambia automáticamente (en la app **y** en el cobro). **No hay que tocar nada.**

### Opciones (variables de entorno del VPS, todas opcionales)

| Variable | Para qué |
|---|---|
| `USD_A_COP_MARGEN=2` | Agrega un **% de margen** sobre la tasa (ej: 2% para cubrirte de la variación). |
| `USD_A_COP_TTL_MIN=360` | Cada cuántos minutos se vuelve a consultar la tasa (por defecto 360 = 6 h). |
| `USD_A_COP=3200` | **Fuerza una tasa fija** y desactiva lo automático (por si algún día querés fijarla). |

## Tabla de ejemplo (con la TRM de hoy: 3.072,27)

| Plan | USD | COP que se cobra |
|---|---|---|
| 1 Mes | US$15 | $46.100 |
| 3 Meses | US$39 | $119.800 |
| 6 Meses | US$69 | $212.000 |
| 1 Año | US$120 | **$368.700** |
| Vouchers 1 Mes | US$3 | $9.200 |
| Vouchers 3 Meses | US$8 | $24.600 |
| Vouchers 6 Meses | US$15 | $46.100 |
| Vouchers 1 Año | US$30 | $92.200 |

*(Los valores cambian solos cuando cambia el dólar — esta tabla es solo un ejemplo.)*

## Endpoints / archivos

| Dónde | Qué |
|---|---|
| `GET /precios` (VPS) | `{ ok:true, usdACop:3200, moneda:"COP", planes: { "1a": { usd:120, cop:384000, ... } } }` |
| `functions/index.js` | `USD_A_COP`, `montoCop(plan)` (lo usan **Mercado Pago** y **Rapid**) |
| `lib/services/precios_service.dart` | Trae la tasa del VPS y formatea el COP (`$384.000`) |
| `lib/plan_model.dart` | `plan.precioCop` y `plan.precioCopTexto` |
| `activar_membresia` / `renovar_membresia` | Muestran `US$120` **y** `= $384.000 COP` |

## Siquerés un COP distinto en un plan puntual

Poné `precioCop` en ese plan dentro de `PLANES_MP` (manda sobre la tasa):

```js
'1a': { precio: 120, meses: 12, titulo: '1 Año StarkGo', tipo: 'completo', precioCop: 399000 },
```

## Verificar que quedó bien

```bash
curl http://5.161.88.42:3000/precios
```
Debe mostrar `usdACop` y el `cop` de cada plan. Si ves otro número al cobrar,
es porque el VPS todavía tiene la versión vieja de `functions/index.js`:
subilo de nuevo y reiniciá el servicio.
