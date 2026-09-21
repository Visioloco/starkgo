# 📌 IPs del MikroTik (leases DHCP) — ver la IP de la antena sin entrar a WinBox

Cuando conectás una antena, el MikroTik le asigna una IP por **DHCP**. Para
registrar el cliente necesitás **esa IP** (el campo *IP QUE LIMITA MEGAS* →
`clientes.ipatn`) y antes había que entrar a WinBox a buscarla.

Ahora la ves **desde la app**, la buscás, la usás al crear el cliente y la podés
dejar **fija y marcada** en el router.

---

## 1. Cómo usarlo

**Desde el menú (☰) → «IPs del MikroTik»**

1. Se abre la lista de equipos que el router tiene en el DHCP, con:
   - **IP**, **MAC**, **nombre del equipo** (`host-name`), **D** (dinámica) / **F** (fija),
   - y **quién la usa según la app**: *Cliente: Juan*, *Sectorial: Base 1* o *Sin registrar*.
2. **Buscador** (arriba): escribís la IP, la MAC o el nombre (ej. `ubnt`, `192.168.10.57`)
   y filtra al instante. Chips de filtro: *Dinámicas · Sin registrar · Estáticas · Stark · Todas*.
3. Botón **«Usar esta IP»** → te lleva a **Crear cliente** con la IP ya cargada
   (si esa IP ya es de un cliente, te avisa antes).
4. Botón **«Marcar StarkGo»** → le pone nombre, y el lease queda:
   - **ESTÁTICO** (la antena **no cambia** de IP),
   - comentario `StarkGo <nombre>` en el MikroTik,
   - la IP en la **address-list `starkgo`**.

**Desde el alta de cliente:** en *Red y Equipos*, debajo del campo de la IP,
hay un botón **«No sé la IP de la antena · buscarla en el MikroTik»** → abre la
misma lista; al tocar *Usar esta IP* **vuelve y la deja cargada** en el campo.

**Automático:** al guardar un cliente nuevo, la app **marca sola** el lease de
esa IP (estático + comentario con el nombre del cliente + lista `starkgo`). Así
el router queda identificable y la antena conserva su IP sin que hagas nada.

---

## 2. Por dónde lee (y por dónde escribe)

| Situación | Camino | Velocidad |
|---|---|---|
| Panel local conectado (misma red o por el túnel) | **Directo al router** (API 8728/8729): `/ip dhcp-server lease` | Instantáneo |
| Sin panel local | **Por el VPS** (`GET /mikrotik/leases`), que habla REST con el router | 1-3 s |

El "marcar" usa el mismo criterio: primero directo al router y, si no se puede,
por el VPS (`POST /mikrotik/lease/marcar`). Si el REST tampoco puede, el VPS
**encola** la acción `marcarLease` y el MikroTik la aplica en el próximo ciclo
del scheduler (1-5 min). En la app siempre te dice qué pasó.

---

## 3. Qué escribe exactamente en el router

```routeros
# 1) El lease pasa a ESTÁTICO (para que el DHCP no le cambie la IP)
/ip dhcp-server lease make-static <id del lease>

# 2) Comentario identificable
/ip dhcp-server lease set <id> comment="StarkGo Juan Pérez"

# 3) Queda en una address-list propia (para tus reglas de firewall)
/ip firewall address-list add list=starkgo address=192.168.10.57 \
    comment="StarkGo Juan Pérez"
```

Todo es **idempotente**: si ya era estática no la vuelve a convertir, y si la IP
ya está en la lista no la duplica.

---

## 4. Requisitos

| Para… | Hace falta |
|---|---|
| Leer/marcar **por el VPS** | El router con el servicio **`www-ssl`** (o `www`) habilitado — el mismo que ya usa el *tracking de consumo* |
| Leer/marcar **directo** | El panel local conectado (API `8728`, o `8729` con SSL) |
| Escribir en el router | Que el usuario del MikroTik tenga permiso sobre `/ip/dhcp-server/lease` y `/ip/firewall/address-list` (con `admin` alcanza) |
| Leer/marcar | La **API Key** del VPS cargada (`config_mikrotik/{uid}.vpsApiKey`) |

---

## 5. Endpoints nuevos del VPS

| Método | Ruta | Para qué |
|---|---|---|
| GET | `/mikrotik/leases?apikey=…` | Lista los leases del DHCP del router (normalizados) |
| POST | `/mikrotik/lease/marcar` | `{apikey, ip, nombre}` → estático + comentario + address-list |
| — | acción de cola `marcarLease` | Respaldo: el router lo aplica en el próximo ciclo |

Archivos:

| Parte | Archivo |
|---|---|
| App · pantalla | `stark_go/lib/pages/leases_mikrotik/leases_mikrotik_widget.dart` |
| App · servicio | `stark_go/lib/services/mikrotik_leases_service.dart` |
| App · router local | `stark_go/lib/services/mikrotik_local_api.dart` (`obtenerLeasesDhcp`, `marcarLeaseDhcp`) |
| App · VPS | `stark_go/lib/services/vps_service.dart` (`obtenerLeases`, `marcarLease`) |
| Alta de cliente | `stark_go/lib/pages/crear_usuario/crear_usuario_widget.dart` (precarga + botón) |
| Menú | `stark_go/lib/pages/home/home_widget.dart` (entrada «IPs del MikroTik») |
| VPS | `functions/index.js` (`/mikrotik/leases`, `/mikrotik/lease/marcar`, acción `marcarLease`) |

---

## 6. Problemas típicos

| Síntoma | Causa / solución |
|---|---|
| «No pude leer los equipos del MikroTik» | El VPS no llega al router o `www-ssl` está apagado. Probá desde el panel local (directo). El texto de error dice qué camino falló |
| La lista sale vacía | El router no tiene leases todavía (las antenas se conectan y aparecen), o estás filtrando por *Dinámicas* y son fijas |
| «Esa IP ya está en uso» | Esa IP figura como cliente/sectorial en la app: revisá antes de usarla |
| No queda **estática** | El usuario del MikroTik no tiene permiso para `make-static`, o el REST falló: la app igual encola el comando (revisá la cola) |
| Se marcó pero la antena cambió de IP | Pasó a estática **después** de que el DHCP ya había reasignado: volvé a marcarla con la IP nueva |

---

## 7. Relacionado

| Tema | Documento |
|---|---|
| Antenas y VPN (abrir airOS, IPs de antenas) | `CONFIGURAR_VPN.md` / `VPN_INSTRUCCIONES.md` |
| Cola del VPS (por qué a veces tarda 1-5 min) | `VPS_INSTRUCCIONES.md` (§5) |
| Portal de morosos (usa la address-list y `ip-binding`) | `PORTAL_MOROSOS.md` |
