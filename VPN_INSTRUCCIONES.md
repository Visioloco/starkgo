# ⚠️ Manual unificado → ver `CONFIGURAR_VPN.md`

> **Este archivo quedó como HISTORIAL.** Todo lo del túnel (mapa de IPs, peers,
> subredes de antenas, netmap, el lado MikroTik y el diagnóstico) se unificó en
> **`CONFIGURAR_VPN.md`**, que es el único manual del túnel.
>
> Lo de la app también se unificó: la pantalla **Configurar VPN** tiene TODO el
> túnel, y **Config. MikroTik** quedó sólo con la configuración del router
> (datos, API Key, scheduler, portal de morosos y regla de bloqueo).

---

Módulo para conectarse por **WireGuard** (paquete `wireguard_flutter`) a la red
privada de antenas (`10.10.15.0/24`) y abrir la interfaz **airOS** de cada antena
desde un WebView.

---

## 1. Arquitectura

```
lib/
└── services/
    ├── vpn_controller.dart        → Fachada + tipos (VpnStatus, VpnConfig) +
    │                                carga segura de config desde Firestore.
    ├── vpn_controller_io.dart     → Implementación real (wireguard_flutter).
    │                                Flujo iOS (WireGuardKit) preparado/comentado.
    ├── vpn_controller_stub.dart   → Stub web (el plugin no compila en web).
    └── antenas_service.dart       → Modelo AntenaModel + stream desde Firestore.

lib/pages/vpn/
    ├── vpn_widget.dart            → Switch/indicador de estado + listado de antenas.
    └── antena_webview_page.dart   → WebView airOS (solo con VPN conectado).
```

- **Android**: funciona de una (el sistema pide el permiso VPN al conectar).
- **iOS**: requiere crear el target Network Extension en Xcode (sección 5).
- **Web**: muestra "plataforma no soportada" (el plugin no soporta web).

---

## 2. Datos en Firestore

> ✅ **Desde la app** podés crear/editar estos datos sin tocar la consola:
> **VPN · Antenas → ⚙️ (Configurar) → "Crear / editar configuración"**.
> El formulario genera el par de claves WireGuard, sugiere la IP libre del pool
> (10.10.15.x) y guarda el documento automáticamente.

### 2.1 Configuración del túnel → `vpn_config/{uid}`

Documento por empresa/técnico autenticado (`uid` = `FirebaseAuth.uid`).
Firestore Rules deben restringir lectura/escritura al propio `uid`.

Campos que guarda el formulario (formato B, la app arma el conf en memoria):

```json
{
  "privateKey": "…",            // generada en el dispositivo (o pegada)
  "clientPublicKey": "…",       // se deriva automáticamente (para el Peer en MikroTik)
  "peerPublicKey": "…",         // PublicKey del servidor WireGuard (MikroTik)
  "address": "10.10.15.2/32",   // IP del dispositivo (dinámica desde 10.10.15.0/24)
  "allowedIps": "10.10.15.0/24",
  "endpoint": "10.50.50.2:13231",
  "dns": "1.1.1.1",
  "persistentKeepalive": 25
}
```

> 💡 **Multi-empresa (renta)**: cada empresa/técnico tiene su propio `uid` y por lo
> tanto su propio `vpn_config/{uid}`. Cada MikroTik WireGuard asigna la IP del
> cliente desde **su** pool (p. ej. `10.10.15.x`) — el botón "IP libre" busca la
> primera IP no usada (escanea `antenas` + la propia `vpn_config` de ese usuario).

> ⚠️ **Seguridad**: la `PrivateKey` **nunca** se loguea ni se persiste en el
> cliente. Solo se construye en memoria al conectar (`VpnConfig.toDebugString()`
> enmascara la clave). El tráfico a Firestore ya queda cubierto por las Rules.

### 2.2 Listado de antenas → colección `clientes` (campo `ipatn`)

Las antenas de los clientes **no** están en una colección propia: viven en
`clientes`, en el campo `ipatn`. `AntenasService` consulta `clientes` filtrado
por `propietarioUid` (usuario autenticado) y toma de cada documento:

```json
{
  "nombre": "Juan",
  "apellido": "Pérez",
  "propietarioUid": "<uid del técnico>",
  "ipatn": "10.10.15.10",        // ← IP de la antena (la que se abre en airOS)
  "status": "activo",            // ← estado (activo/en_linea habilita el acceso)
  "usuarioatn": "ubnt",          // credencial airOS (para la futura REST API)
  "claveatn": "…",               // credencial airOS
  "antenaMarca": "Ubiquiti",
  "antenaModelo": "LiteBeam M5"
}
```

- Solo se listan los clientes con `ipatn` no vacío.
- `ipatn` debe estar dentro de `10.10.15.0/24` (hosts 1..254). Las IPs fuera de
  rango se muestran con el badge "IP fuera de rango" y no se pueden abrir.
- `status` aceptado para abrir: `activo` o `en_linea` (chip verde).
  Cualquier otro valor muestra la antena bloqueada.
- El tap solo abre el WebView si el túnel está **conectado**.
- `AntenaModel` ya expone `usuarioAtn`/`claveAtn`/`marca`/`modelo` para el
  futuro reemplazo del WebView por la REST API de RouterOS/airOS.

### 2.2bis Sectoriales → colección `sectoriales`

Los **sectoriales** (bases/sectores propios del proveedor, que no son clientes)
se registran desde la app: **VPN · Antenas → "+ Agregar"** (o el botón
"Registrar sectorial" cuando el túnel está desconectado).

Se guardan en la colección `sectoriales`, con el mismo `propietarioUid` y **la
misma subred** `10.10.x.0/24` de antenas del usuario:

```json
{
  "propietarioUid": "<uid del técnico>",
  "nombre": "Sector A - Torre 1",
  "ip": "10.10.15.20",           // ← debe estar dentro de la subred del usuario
  "estado": "activo",
  "marca": "Ubiquiti",
  "modelo": "PrismStation 5AC",
  "usuarioatn": "ubnt",
  "claveatn": "…",
  "notas": "opcional"
}
```

- El botón **"IP libre"** del formulario sugiere la próxima IP libre escaneando
  `clientes.ipatn` + `sectoriales.ip` + `vpn_config` dentro de la subred.
- Los sectoriales aparecen en el mismo listado de antenas (con íconos de editar
  ✏️ y eliminar 🗑️) y se abren igual en el WebView airOS con el túnel conectado.
- Al registrar o editar una sectorial, si el **Portal de pago** está activo
  (`portalMorosos: true` en Config MikroTik), la app encola automáticamente el
  `ip hotspot ip-binding type=bypassed` de esa IP (por la cola del VPS, se
  aplica en el próximo ciclo del scheduler). Así el portal cautivo NO
  intercepta la interfaz de la sectorial, igual que con los clientes al día.
- Las reglas de Firestore (`firestore.rules`) ya incluyen la colección
  `sectoriales`.

---

## 2.3 VPS — hub WireGuard con peers dinámicos (sin subcarpetas)

El VPS es el **hub WireGuard** (`10.50.50.1/24`, puerto 1234). Cada empresa,
técnico o celular es un **peer** con una IP única del pool `10.50.50.x`. No se
usan subcarpetas por cliente: el estado vive en Firestore y `wg0.conf` se
regenera solo.

### Modelo de datos

- **Firestore colección `wg_peers`** (doc id = clave pública del peer):
  ```json
  {
    "propietarioUid": "<uid del usuario>",
    "ip": "10.50.50.6",
    "nombre": "Técnico - Empresa A",
    "creadoEn": "<timestamp>"
  }
  ```
- **En el VPS** (`/etc/wireguard/`):
  - `wg0.interface.conf` → bloque `[Interface]` (se crea una sola vez con `/wg/init`)
  - `wg0.static.conf` → peers fijos que manejás a mano (MikroTik 1/2, PC)
  - `wg0.conf` → regenerado automáticamente = interface + estáticos + dinámicos
- **Aplicación en vivo** sin caer la interfaz: `wg syncconf wg0 <(wg-quick strip wg0)`.

### Endpoints nuevos en el VPS (puerto 3000)

| Endpoint | Qué hace |
|---|---|
| `GET /wg/info` | Devuelve public key del servidor, puerto y endpoint (autocompleta la app). |
| `POST /wg/register` | Da de alta el peer del usuario, asigna la próxima IP libre del pool y la aplica. |
| `POST /wg/register-mikrotik` | Da de alta el peer **estático** del MikroTik (su IP del túnel + la subred de antenas). Re-verifica la IP del túnel y devuelve `ipReasignada: true` si tuvo que darle otra. |
| `DELETE /wg/peers/:publicKey` | Da de baja el peer (solo el dueño). |
| `POST /wg/init` | **Setup único**: separa `wg0.conf` en interface + estáticos. |

### Setup en el VPS (una vez)

```bash
# 1) Copiar el nuevo index.js (con endpoints /wg/*) y reiniciar el servicio.
cd /ruta/functions && npm install && pm2 restart starkgo-api   # o systemctl restart ...

# 2) Inicializar la separación de wg0.conf (usa un apikey válido de config_mikrotik)
curl -X POST http://5.161.88.42:3000/wg/init \
  -H "Content-Type: application/json" \
  -d '{"apikey":"TU_APIKEY"}'

# 3) Verificar
cat /etc/wireguard/wg0.interface.conf   # solo [Interface]
cat /etc/wireguard/wg0.static.conf      # tus peers fijos (MikroTik, PC)
wg show wg0                             # peers activos
```

### ¿El VPS está actualizado? (verificación en 10 segundos)

```bash
# 1) Versión + endpoints del VPS (NO necesita apikey):
curl -s http://5.161.88.42:3000/
# ✅ Esperado: {"status":"StarkGo API v2.6","endpoints_wireguard":["/wg/info",...],"colas_activas":{...}}
# ❌ Si dice "v2.5" o NO aparece "endpoints_wireguard" → el VPS tiene el index.js
#    viejo: subir functions/index.js y reiniciar el servicio.

# 2) ¿Existe el endpoint que usa la app? (sin apikey debe dar 401, NUNCA 404):
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  http://5.161.88.42:3000/wg/register-mikrotik \
  -H "Content-Type: application/json" -d '{}'
# 401 = el endpoint existe (VPS actualizado; solo falta la apikey)
# 404 = el VPS sigue con una versión sin /wg/register-mikrotik
```

| Mensaje en la app | Causa | Solución |
|---|---|---|
| `El VPS no tiene el endpoint /wg/register-mikrotik (HTTP 404)` | `index.js` viejo en el VPS | Subir `functions/index.js` y reiniciar el servicio |
| `must point to a document, but was "…/…"` (HTTP 500) | La Public Key tiene `/` y se usaba como id de documento en Firestore | Subir `functions/index.js` v2.6+: el peer se guarda con id seguro (base64url) y la clave real en el campo `publicKey` |
| `No autorizado` / `El VPS rechazó la API Key (HTTP 401)` | La `vpsApiKey` guardada en `config_mikrotik/{uid}` no es la que se está enviando | Llenar la API Key y tocar **Guardar** antes de registrar; reintentar |
| `Sin apikey: guardá la configuración del VPS primero` | `config_mikrotik/{uid}.vpsApiKey` vacío en Firestore | Cargar la API Key y guardar la config |
| `Primero generá la IP del túnel del MikroTik` | Falta el paso previo | Tocar **Generar IP del túnel** (es obligatorio antes de registrar) |
| `La subred … ya está en uso por otra empresa` | Otra empresa declaró esa misma red | Declarar otra red o encender el switch **netmap** |
| `No se pudo contactar al VPS (…)` | Sin internet, VPS caído o puerto 3000 cerrado | Revisar conexión y que el servicio Node esté arriba |

> 🕐 **API Key recién generada**: desde `index.js` v2.6 el VPS refresca su cache
> de claves **al instante** cuando no encuentra la apikey (antes podía tardar
> hasta 5 minutos y la app mostraba *No autorizado* justo después de generar o
> rotar la API Key en Config. MikroTik).

### Flujo en la app

1. **VPN · Antenas → ⚙️ → Generar claves**.
2. **"Registrar en el VPS (IP dinámica)"**: la app consulta `/wg/info`
   (autocompleta public key del servidor + endpoint), llama `/wg/register` con tu
   clave pública y el VPS asigna y aplica la próxima IP libre (ej. `10.50.50.6/32`).
3. Guardar → `vpn_config/{uid}` queda con `address` dinámica, `peerPublicKey`
   del VPS y `endpoint = 5.161.88.42:1234`.
4. `AllowedIPs = 10.50.50.0/24, <tu subred de antenas>` → el teléfono alcanza el
   hub y las redes de antenas del MikroTik.

### Subred de antenas por empresa (automática, no editable)

Cada `uid` recibe una **subred `10.10.x.0/24` única** asignada por el VPS la
primera vez que registra su peer (empresa 1 → `10.10.15.0/24`, empresa 2 →
`10.10.16.0/24`, … hasta `10.10.254.0/24`). Se guarda en `vpn_config/{uid}`
como `redAntenas`:

- La app la muestra **solo lectura** (formulario y listado de antenas).
- El listado de antenas valida que cada `ipatn` esté dentro de **esa** subred.
- `AllowedIPs` se autocompleta con la subred asignada.

Con esto los MikroTik nunca comparten subred de antenas detrás del hub → no hay
rutas pisadas. En el peer de cada MikroTik en el VPS agregar su subred:
`AllowedIPs = 10.50.50.X/32, 10.10.X.0/24`.

> ⚠️ **Importante**: no editar `redAntenas` a mano — el VPS la asigna para
> garantizar que sea única. Si necesitás cambiarla, borrá el peer y el campo.

---

### 2.4 Tu red local (opcional) — que las antenas coincidan con tu MikroTik

Por defecto el VPS te asigna una subred de gestión/antenas única
(`10.10.x.0/24`). Si tu red real es otra (lo normal: `192.168.1.0/24`,
`192.168.10.0/24`, `192.168.88.0/24`, …) **podés declararla** desde la app:

**Configurar VPN → "TU RED LOCAL"** —o **Config. MikroTik → Datos del
MikroTik**— (es el mismo dato, se guarda en `config_mikrotik/{uid}`)

| Campo | Ejemplo | Para qué |
|---|---|---|
| `MI SUBRED LOCAL (CIDR)` | `192.168.10.0/24` | La red donde viven tus antenas y tu MikroTik. Se guarda en `config_mikrotik/{uid}.subredLocal` y el VPS la usa como subred de antenas (la expone por el túnel). |
| `MI IP LOCAL / PUERTA DE ENLACE` | `192.168.10.1` | Tu gateway. Se guarda en `config_mikrotik/{uid}.ipLocal`. El generador de IPs de antena lo **excluye** para no pisarlo. |
| `IP DEL MIKROTIK (EN TU RED LOCAL)` | `192.168.10.1` | La IP con la que el panel (VPS) llega al router **por el túnel**. Debe estar dentro de la subred local. |

Si dejás los campos **vacíos**, todo funciona como antes: el VPS asigna una
`10.10.x.0/24` libre.

**Qué pasa cuando declarás tu red:**

1. Tocás **Registrar en el VPS** (tarjeta "Peer del MikroTik en el VPS").
2. El VPS **valida que esa subred no la use otra empresa**:
   - libre → la guarda en `vpn_config/{uid}.redAntenas`, agrega `ip route <tu subred> dev wg0`
     y el peer queda con `AllowedIPs = <túnel>/32, <tu subred>`.
   - ocupada → responde `409` con el motivo y la app lo muestra en rojo
     (elegí otra subred, ej. `192.168.20.0/24`).
3. La subred queda guardada y normalizada (`192.168.10.5/24` → `192.168.10.0/24`).
4. El botón **"Generar IP"** del alta de cliente ahora genera `ipatn` **dentro de
   tu subred local**, salteando el gateway → la antena y el MikroTik coinciden.

> ⚠️ **Regla**: la subred declarada debe ser la **misma** que tenés en el MikroTik
> (IP → Addresses / IP → Routes). Si declarás una subred que tu MikroTik no
> conoce, el VPS no va a poder llegar a las antenas.

#### Doble control de la IP del túnel (`10.50.50.x`)

La IP del túnel **también** debe ser única, y se controla en los dos lados:

| Dónde | Qué revisa |
|---|---|
| **App** (`VpsService.generarIpTunelMikrotik`) | `config_mikrotik.mikrotikTunelIp` de todas las empresas + `wg_peers.ip` (teléfonos) + tu propio `vpn_config.address`. Devuelve la primera libre del pool `.2`–`.250`. |
| **VPS** (`wgIpTunelEnUso` → `wgIpSiguienteLibre`) | Al registrar el MikroTik vuelve a verificar contra `wg_peers`, `config_mikrotik.mikrotikTunelIp` y **el `wg0.conf` real**. Si ya la tenía otro equipo, **reasigna** la próxima libre y la devuelve en la respuesta (`ipReasignada: true`). |

Con esto no importa si dos técnicos generan la IP al mismo tiempo o si Firestore
quedó desincronizado: **el servidor es la fuente de verdad** y te avisa en la app
(`⚠️ Esa IP del túnel ya la tenía otro equipo… actualizala en tu MikroTik`).

**En el MikroTik** esa subred ya existe (es tu LAN), así que no hay que
re-IP-ear antenas ni agregar NAT: el router ya es el gateway de sus antenas.
Solo asegurate de que el peer reconozca la red del hub:

```routeros
# El peer del VPS le permite al router enviar/recibir hacia el hub
/interface wireguard peers print
# Allowed Address debe incluir 10.50.50.0/24 (vuelta hacia el VPS)
```

---

### 2.5 Modo NAT (netmap) — varias empresas con la MISMA red local

Escenario clásico: 5 empresas, todas con el MikroTik en `192.168.1.1` y sus
sectoriales/antenas recibiendo DHCP `192.168.1.x`. **Ese `192.168.1.1` repetido
no molesta para nada** (es local de cada router: colas de velocidad, morosos,
DHCP y navegación funcionan igual). Lo único que no puede repetirse es la
**subred que cruza el túnel**.

Con el switch **"Uso NAT (netmap) para las antenas"** activado:

| Dónde | Qué pasa |
|---|---|
| La subred del túnel | La asigna el VPS automáticamente y es única (`10.10.15.0/24`, `10.10.16.0/24`, …). Tu red local **no** se declara, así que puede repetirse. |
| Tu red local | Sigue intacta: `192.168.1.1`, DHCP `192.168.1.x`, colas, morosos… |
| La app | Abre cada antena por su **IP virtual** dentro de la subred del túnel (misma última octeta): `192.168.1.20` → `10.10.15.20`. |
| Tu MikroTik | Traduce con **una sola regla** `netmap` (te la da la app lista para copiar). |

**Pasos:**

1. Config. MikroTik → **Tu red local**:
   - `MI SUBRED LOCAL (CIDR)` → `192.168.1.0/24` (tu red real)
   - `MI IP LOCAL / PUERTA DE ENLACE` → `192.168.1.1`
   - Switch **"Uso NAT (netmap) para las antenas"** → **ON**
2. **Generar IP del túnel** → **Registrar en el VPS**.
   *La app te autocompleta la IP del MikroTik con la virtual (`10.10.15.1`) y te
   muestra la subred del túnel asignada.*
3. Copiá el comando **netmap** que aparece en la tarjeta y pegalo en tu MikroTik:

```routeros
/ip firewall nat add chain=dstnat in-interface=wg1 \
  dst-address=10.10.15.1-10.10.15.254 action=netmap \
  to-addresses=192.168.1.1-192.168.1.254 place-before=0 comment="StarkGo netmap"
```

> 🔁 El rango debe ser de **mismo tamaño** (1↔1) y conservar la última octeta.
> Con eso, `10.10.15.20` llega al airOS que está en `192.168.1.20`, en **todos
> los puertos** (http, https, ssh, ICMP).

4. Tocá **"Probar la regla netmap"** (misma tarjeta): si responde ✅ la
   traducción está bien. Si falla, te dice exactamente qué revisar.
5. En **VPN · Antenas** cada equipo se ve como `192.168.1.20 → 10.10.15.20`
   y se abre con un tap. Cada tarjeta tiene un **botón azul de prueba** que
   verifica esa antena en particular (http/https) y te dice si responde.

**Comparación de los dos modos**

| | Modo normal (sin netmap) | Modo netmap |
|---|---|---|
| Subred del túnel | Tu red declarada (`192.168.10.0/24`) o la auto `10.10.X.0/24` | Siempre la auto `10.10.X.0/24` (única) |
| ¿Tu red local puede repetirse en otra empresa? | **No** (el VPS la rechaza) | **Sí** ✅ |
| Cambios en tu red | Ninguno | Una regla NAT por MikroTik |
| `ipatn` (colas de velocidad) | Sin cambios | Sin cambios (sigue siendo la IP real) |
| IP del MikroTik en la app | La real | La virtual (`10.10.15.1`, se autocompleta) |

---

## 3. Cómo probar

> 📖 La app incluye una **guía paso a paso integrada**: **VPN · Antenas → "Guía de configuración"** (con los comandos de VPS y MikroTik y botón copiar).

1. **VPS**: subir el nuevo `functions/index.js`, reiniciar el servicio y ejecutar
   `POST /wg/init` (ver sección 2.3).
2. `flutter pub get`
3. Correr en Android: `flutter run`
4. Home → menú → **VPN · Antenas** → **⚙️ (Configurar)** → completar:
   - **Generar claves**
   - **Registrar en el VPS** (asigna la IP dinámica `10.50.50.x` y autocompleta
     public key del servidor + endpoint)
   - Guardar.
5. Volver a **VPN · Antenas** → activar el switch.
6. Con el túnel conectado, tocar una antena → se abre airOS (`http://10.10.15.x`).

---

## 3.5 Regla de firewall obligatoria para bloquear morosos 🔥

Cuando ponés un cliente en **mora**, la app agrega su IP a la address-list
**`morosos`** (`/ip firewall address-list add list=morosos address=X comment="Cliente"`).
Para que esa IP realmente se quede **sin internet**, el MikroTik debe tener esta
regla de firewall (crearla **una sola vez**):

```routeros
/ip firewall filter add chain=forward src-address-list=morosos action=drop comment="Bloqueo a Morosos"
```

En Winbox: **IP → Firewall → Filter Rules → +** → Chain `forward` · Src. Address
List `morosos` · Action `drop` · Comment `Bloqueo a Morosos`.

> También está documentada dentro de la app: **Config MikroTik → Paso 3 — Regla de
> bloqueo a morosos** (con botón copiar).

---

## 4. Próximos pasos (reemplazo del WebView por REST)

`AntenaModel` y `AntenasService` ya exponen `id`, `nombre`, `ip`, `estado`, por lo
que se puede añadir un `AirOsRestClient` (login + `/rest` de RouterOS / API airOS)
usando la misma `ip` y las credenciales que se guarden (nunca en el cliente).

---

## 5. iOS — Network Extension (configuración pendiente en Xcode)

El flujo ya está **preparado/comentado** en `vpn_controller_io.dart`
(sección "FLUJO iOS PREPARADO"). Mientras no se haga, la app en iOS muestra un
aviso y `startVpn` devuelve un error claro. Para habilitarlo:

1. **Target** → `+` → **App Extension** → **Packet Tunnel Provider** → `WGExtension`
   (bundle id `com.starkgo.net.cardenCode.WGExtension`).
2. Agregar **WireGuardKit** (Swift Package: `wireguard-apple`) al target.
3. `WGExtension/Info.plist`:
   - `NSExtensionPointIdentifier = com.apple.networkextension.packet-tunnel`
   - `NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).PacketTunnelProvider`
4. Entitlements (Runner **y** WGExtension):
   - `com.apple.developer.networking.networkextension` = `[packet-tunnel-provider]`
   - `com.apple.security.application-groups` = `[group.com.starkgo.net.cardenCode]`
5. `PacketTunnelProvider.swift` → clase `NEPacketTunnelProvider` que parsea
   `providerConfiguration["wgQuickConfig"]` con
   `TunnelConfiguration(fromWgQuickConfig:)` (ver plantilla comentada en
   `vpn_controller_io.dart`).
6. En `vpn_controller_io.dart` cambiar
   `_iosNetworkExtensionConfigurado = false` → `true`.

Con eso, `startVpn` entrega el `wgQuickConfig` y el
`providerBundleIdentifier = "...WGExtension"` sin tocar más la app.

---

## 6. Builds

- Android: `minSdk 21+` (default de Flutter). Se agregó
  `android:usesCleartextTraffic="true"` para permitir airOS por `http://`.
- El paquete no soporta **web**: la fachada usa un import condicional
  (`dart.library.io`) para que el build web siga compilando.
