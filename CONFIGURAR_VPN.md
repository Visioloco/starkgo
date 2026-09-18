# 🌐 Manual ÚNICO del Túnel — "Configurar VPN"

> **Todo lo del túnel vive acá.** En la app, la pantalla **Configurar VPN**
> (menú lateral → *VPN · Antenas* → **⚙️ Configurar**) es el único lugar donde se
> configura el túnel: las claves del teléfono, la IP del MikroTik, su Public Key
> como peer del VPS, tu red local y el modo netmap.
>
> **Config. MikroTik** quedó solo para el router: datos (IP/usuario/clave),
> API Key del VPS, scheduler, script, portal de morosos y regla de bloqueo.
>
> Este documento reemplaza a `VPN_INSTRUCCIONES.md` (que queda como historial).

---

## 1. Mapa de direcciones (todas las IP juntas)

| Qué | Valor | Dónde se configura |
|---|---|---|
| IP pública del VPS | `5.161.88.42` | fija |
| API / webhooks del VPS | `http://5.161.88.42:3000` | fija |
| **Hub WireGuard (VPS)** | `10.50.50.1/24`, puerto `1234` | VPS (`/etc/wireguard/wg0.*`) |
| Pool de **teléfonos/técnicos** | `10.50.50.2` … `10.50.50.250` | automático (`/wg/register`) |
| **IP del MikroTik en el túnel** | `10.50.50.Y/32` (Y único) | tarjeta *IP del túnel* → `mikrotikTunelIp` |
| **Subred de gestión/antenas de tu empresa** | `10.10.X.0/24` (X = 15…254, única) | la asigna el VPS al registrar (`redAntenas`) |
| Puerto de escucha de `wg1` (MikroTik) | `13231` | el MikroTik inicia la conexión; no hace falta abrirlo |
| IP real de cada antena | p. ej. `192.168.1.20` (tu red local) | `clientes.ipatn` / `sectoriales.ip` |
| IP **virtual** de esa antena (sólo netmap) | `10.10.X.20` (misma última octeta) | se calcula sola en la app |
| Puertos de las antenas (airOS/WebFig) | `80`, `443`, `8080`, `8085` | — |
| API Key del VPS | `sg_xxxxxxxx_yy` | *Config. MikroTik → Tu clave de acceso* |

**Regla de oro:** el teléfono y el MikroTik **se ven por la subred del túnel**
(`10.10.X.0/24`); esas IPs **no existen en tu red física**. La app traduce
sola: `192.168.1.20` → `10.10.X.20` cuando usás netmap.

---

## 2. Direcciones del pool: cómo se reparten y por qué no chocan

- **IP del MikroTik** (`10.50.50.Y`): la app busca la primera libre entre
  *todos* los `config_mikrotik.mikrotikTunelIp`, los `wg_peers.ip` y tu
  `vpn_config.address`. El **VPS la vuelve a verificar** al registrar contra
  esas 3 fuentes + el `wg0.conf` real; si ya la tenía otro equipo te devuelve
  otra y la app te avisa *"⚠️ Esa IP del túnel ya la tenía otro equipo…"*.
- **Subred de antenas** (`10.10.X.0/24`): la asigna el VPS **una sola vez por
  empresa** (`vpn_config.redAntenas`). No se edita a mano: garantiza que dos
  empresas no expongan la misma red por el túnel.
- **En modo netmap** tu red local **no se declara** al VPS (puede repetirse
  entre empresas); en modo normal **sí** se declara y el VPS la rechaza si otra
  empresa ya la usa.

---

## 3. Paso a paso en la app (pantalla **Configurar VPN**)

### 3.1 Este teléfono / técnico (peer dinámico)
1. Menú → **VPN · Antenas** → **⚙️ Configurar** (o el botón *Crear / editar
   configuración*).
2. **Generar claves** (o pegar tu clave privada existente).
3. **Registrar en el VPS (IP dinámica)** → la app llama `/wg/info` (trae la
   public key del servidor + endpoint) y `/wg/register` (te asigna
   `10.50.50.x`).
4. **Guardar configuración** → queda en `vpn_config/{uid}`.
5. En **VPN · Antenas**: activar el switch del túnel (debe decir *Conectado*).

> La tarjeta **"Tu clave pública"** es la que va como *Peer* en el MikroTik
> (sección 5).

### 3.2 Lado MikroTik (sección **"MikroTik (lado del túnel)"**)
1. **IP del túnel del MikroTik** → *Generar IP del túnel* → te da `10.50.50.Y`.
   Esa IP va en el router: **IP → Addresses → + → Address:** `10.50.50.Y/24`,
   **Interface:** `wg1`.
2. **Public Key de tu MikroTik (wg1)** → *Winbox → WireGuard → doble clic en
   wg1 → campo Public Key* → pegar → **Registrar peer del MikroTik en el VPS**.
   · Esperá el chip verde **"Registrado en el VPS"**.
   · Si sale un recuadro rojo, ahí está el motivo exacto (con el código HTTP).
3. **Tu red local** (opcional pero recomendado): `MI SUBRED LOCAL` (ej.
   `192.168.10.0/24`) y `MI IP LOCAL / PUERTA DE ENLACE` (ej. `192.168.10.1`)
   → **Guardar red local**.
4. **Switch "Uso NAT (netmap)"** → sólo si tu red local puede repetirse en otra
   empresa (ej. todos usan `192.168.1.x`). Al activarlo aparece la tarjeta con
   el **comando netmap** y el botón **Probar la regla netmap**.

### 3.3 Antes de registrar, tener a mano
- **API Key del VPS** guardada en *Config. MikroTik → Tu clave de acceso*
  (la tarjeta del túnel te muestra si falta).
- La **Public Key de wg1** copiada del router.
- La **IP del túnel generada** (paso 1 de 3.2): el peer del VPS queda amarrado
  a esa IP.

---

## 4. Qué se guarda en Firestore

| Colección / doc | Campos del túnel |
|---|---|
| `vpn_config/{uid}` | `endpoint`, `privateKey`, `clientPublicKey`, `address` (10.50.50.x/32), `allowedIPs`, `dns`, `persistentKeepalive`, `peerPublicKey`, **`redAntenas`** (subred de antenas asignada) |
| `config_mikrotik/{uid}` | `vpsApiKey`, `mikrotikIp`, `mikrotikUser`, `mikrotikPass`, **`mikrotikTunelIp`**, **`mikrotikPublicKey`**, **`mikrotikRegistradoEn`**, **`subredLocal`**, **`ipLocal`**, **`usarNetmap`**, `portalMorosos`, `schedulerMinutos` |
| `wg_peers/{id}` | `publicKey` (clave real), `ip` (10.50.50.x), `nombre`, `propietarioUid`, `creadoEn` |

> 🔑 **ID seguro de los peers:** el id del documento es la Public Key pasada a
> **base64url** (`+`→`-`, `/`→`_`) porque Firestore **no admite `/` en un id**.
> La clave original queda en el campo `publicKey`, que es la que se usa para
> `wg set` y para regenerar `wg0.conf`. (Fix v2.6: antes fallaba con HTTP 500.)

---

## 5. El VPS — hub WireGuard (`functions/index.js` en `5.161.88.42`)

### 5.1 Endpoints del túnel (puerto 3000)

| Endpoint | Qué hace |
|---|---|
| `GET /` | Salud + versión (**v2.6**) + lista `endpoints_wireguard` (sirve para verificar el despliegue) |
| `GET /wg/info` | Public key del servidor, puerto, endpoint y pool (autocompleta la app) |
| `POST /wg/register` | Alta del **teléfono**: asigna la próxima IP libre del pool y la aplica |
| `POST /wg/register-mikrotik` | Alta del **MikroTik** (peer estático): IP del túnel + subred de antenas; re-verifica la IP y devuelve `ipReasignada` |
| `DELETE /wg/peers/:publicKey` | Baja del peer (solo el dueño) |
| `POST /wg/init` | Setup único: separa `wg0.conf` en `interface` + `static` |

### 5.2 Archivos en el VPS (`/etc/wireguard/`)

- `wg0.interface.conf` → bloque `[Interface]` (se crea una sola vez con `/wg/init`)
- `wg0.static.conf` → peers fijos (MikroTik, PC) que manejás a mano
- `wg0.conf` → **regenerado** = interface + estáticos + peers de `wg_peers`
- Aplicación en vivo sin caer la interfaz: `wg syncconf wg0 <(wg-quick strip wg0)`

### 5.3 Verificar que el VPS está actualizado (10 segundos)

```bash
curl -s http://5.161.88.42:3000/
# ✅ Esperado: {"status":"StarkGo API v2.6","endpoints_wireguard":[...],"colas_activas":{...}}
# ❌ Si dice "v2.5" o NO aparece endpoints_wireguard → falta subir index.js

curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  http://5.161.88.42:3000/wg/register-mikrotik -H "Content-Type: application/json" -d '{}'
# 401 = el endpoint existe (VPS al día)   404 = versión vieja
```

### 5.4 API Key: validación y cache

La **API Key** (`config_mikrotik.vpsApiKey`) autentica todo. Desde v2.6, si el
VPS **no encuentra** la clave en su cache, **refresca al instante** (máx. 1
refresco cada 10 s): antes podía tardar hasta 5 minutos y la app mostraba
*"No autorizado"* justo después de generar/rotar la API Key.

---

## 6. El MikroTik (interfaz `wg1`)

### 6.1 En Winbox
1. **WireGuard → +** → nombre `wg1`, `listen-port 13231` (el router inicia la
   conexión, no hace falta abrir puertos en el ISP).
2. **IP → Addresses → +** → `10.50.50.Y/24` · Interface `wg1`
   (la IP que generó la app: tarjeta *IP del túnel*).
3. **WireGuard → Peers → +** dentro de `wg1`:
   - **Public Key:** la del **servidor VPS** (la trae la app al registrar; en
     `vpn_config.peerPublicKey`).
   - **Endpoint:** `5.161.88.42` puerto `1234`.
   - **Allowed Address:** `10.50.50.0/24` ← **obligatorio** (vuelta hacia el
     hub y hacia los teléfonos). Si usás netmap, agregá también
     `10.10.X.0/24`.
   - **Persistent Keepalive:** `10s`.
4. **IP → Routes → +** → Dst `10.10.X.0/24` (tu subred de antenas) → Gateway
   `wg1`. *En modo netmap NO se agrega esta ruta: se traduce con la regla NAT.*
5. **IP → Firewall → Filter:** aceptar UDP `1234` de entrada, aceptar
   `established,related` y aceptar `in-interface=wg1`.

### 6.2 En modo netmap (una sola regla)
```routeros
/ip firewall nat add chain=dstnat in-interface=wg1 \
  dst-address=10.10.X.1-10.10.X.254 action=netmap \
  to-addresses=192.168.1.1-192.168.1.254 place-before=0 \
  comment="StarkGo netmap"
```
> La app te da este comando **ya completado** con tus datos (tarjeta *Tu red
> local* → *Uso NAT (netmap)*). Se pega **una sola vez**.
> Con eso `10.10.X.20` llega al equipo que está en `192.168.1.20`, en **todos
> los puertos** (http, https, ssh, ICMP). Tu red local y tu DHCP quedan igual.

### 6.3 Modo normal vs netmap

| | Modo normal (sin netmap) | Modo netmap |
|---|---|---|
| Subred del túnel | Tu red declarada (`192.168.10.0/24`) o la auto `10.10.X.0/24` | Siempre la auto `10.10.X.0/24` (única) |
| ¿Tu red local puede repetirse en otra empresa? | **No** (el VPS la rechaza) | **Sí** ✅ |
| Cambios en tu red | Ninguno | **Una** regla NAT por MikroTik |
| `ipatn` (colas de velocidad) | Sin cambios | Sin cambios (sigue siendo la IP real) |
| IP del MikroTik en la app | La real | La virtual (`10.10.X.1`, se autocompleta) |
| Cómo se abre una antena en la app | `192.168.1.20` | `192.168.1.20 → 10.10.X.20` |

---

## 7. Las antenas (por dónde se abren)

- Se registran en la app como **cliente** (`clientes.ipatn`) o como
  **sectorial** (`sectoriales.ip`); la IP debe estar **dentro de tu subred de
  antenas** (`10.10.X.0/24` en netmap, o de tu red declarada en modo normal).
- **Para abrirlas remotamente:** *VPN · Antenas* → switch del túnel
  **Conectado** → tocar la antena (se abre airOS/WebFig en el WebView).
- Cada tarjeta tiene un **botón de prueba** que intenta http, https y los
  puertos `8085`/`8080` y te dice si el equipo respondió.
- El botón **"Probar la regla netmap"** (en *Configurar VPN*) prueba la IP
  virtual del **router** (`10.10.X.1`): si responde ✅, la traducción funciona.

---

## 8. Diagnóstico rápido

### 8.1 Errores al registrar el peer del MikroTik (los típicos)
La app ahora muestra el motivo **con el código HTTP** en un recuadro rojo
debajo del botón, además del aviso emergente:

| Mensaje | Causa | Solución |
|---|---|---|
| `El VPS no tiene el endpoint /wg/register-mikrotik (HTTP 404)` | `index.js` viejo en el VPS | Subir `functions/index.js` y reiniciar el servicio |
| `must point to a document, but was "…/…"` (HTTP 500) | Public Key con `/` usada como id de documento | Subir `index.js` **v2.6+** (id seguro base64url) |
| `No autorizado` / `El VPS rechazó la API Key (HTTP 401)` | La `vpsApiKey` guardada no es la que se envía | Cargar/guardar la API Key en *Config. MikroTik* y reintentar |
| `Sin API Key del VPS: cargala en Config. MikroTik…` | `config_mikrotik.vpsApiKey` vacío | Completar *Tu clave de acceso* y **Guardar** |
| `Primero generá la IP del túnel del MikroTik` | Falta el paso previo | Tocar **Generar IP del túnel** |
| `La subred … ya está en uso por otra empresa` | Otra empresa declaró esa red | Declarar otra o activar **netmap** |
| `Esa PublicKey ya está registrada como peer dinámico` | Esa clave se usó como teléfono | Usar la Public Key de `wg1` del router |
| `No se pudo contactar al VPS (…)` | Sin internet / VPS caído / puerto 3000 cerrado | Revisar conexión y que el servicio Node esté arriba |

### 8.2 Si la antena no abre
1. ¿El switch del túnel dice **Conectado**? (si no, activalo)
2. ¿La antena figura como *activo/en_linea* y sin el badge **"fuera de rango"**?
3. ¿Registraste el peer del MikroTik (chip verde)? → `wg show wg0` en el VPS
   debe listar tu peer con `allowed-ips` incluidos.
4. En netmap: ¿pegaste la regla NAT y "Probar la regla netmap" da ✅?
5. ¿El firewall del MikroTik deja pasar `in-interface=wg1`?

### 8.3 Comandos útiles en el MikroTik
```routeros
/interface wireguard print
/interface wireguard peers print        # tu peer hacia el VPS (handshake)
/ip address print                       # 10.50.50.Y/24 en wg1
/ip route print                         # ruta 10.10.X.0/24 -> wg1 (modo normal)
/ping 10.10.X.1 count=3                 # IP virtual del router (netmap)
/ping 192.168.1.20 count=3              # la antena real, desde el router
/ip firewall nat print                  # regla netmap
/ip firewall filter print
```

---

## 9. Qué NO es túnel (dónde buscar cada cosa)

| Tema | Dónde |
|---|---|
| **Túnel**: IPs, peers, netmap, subredes de antenas, acceso remoto | **este manual** |
| En la app: claves, IP del MikroTik, peer del MikroTik, red local, netmap | Pantalla **Configurar VPN** |
| En la app: datos del router, API Key, scheduler, script, portal de morosos, regla de bloqueo | Pantalla **Config. MikroTik** |
| Portal de pago para morosos (hotspot + bindings) | `PORTAL_MOROSOS.md` |
| Pagos con tarjeta/PSE | `VPS_RAPID_PAGOS.md` |
| Pagos con PayPal | `PAYPAL_INSTRUCCIONES.md` |
| Precios y tasa USD→COP | `PRECIOS_TASA_CAMBIO.md` |
| Planes y campo `plan` (vouchers) | `VPS_INSTRUCCIONES.md` |
| Historial del módulo VPN (versión anterior) | `VPN_INSTRUCCIONES.md` |

> 📌 **Resumen de una línea:** todo lo que empiece con `10.50.50.x`
> (teléfonos/MikroTik), `10.10.X.0/24` (antenas por el túnel) o *netmap* se
> configura en **Configurar VPN**; lo demás del router y la mora, en
> **Config. MikroTik**.




