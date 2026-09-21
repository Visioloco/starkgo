# 🛡️ Blindaje del administrador — «mi teléfono no me pide PIN»

Cuando estás **creando fichas** o **configurando el hotspot**, tu propio teléfono
no tiene que autenticarse con una ficha/PIN en el portal cautivo. Con esta
función tu equipo queda **`bypassed`** en el MikroTik
(`/ip hotspot ip-binding ... type=bypassed`) y podés seguir creando pines sin
loguearte.

> ✅ Se aplica por **MAC** y/o por **IP**, y opcionalmente **automáticamente**
> cada vez que creás fichas.

---

## 1. Cómo usarlo (2 minutos)

1. Compilá e instalá la **APK nueva**.
2. Conectate al Wi-Fi del MikroTik y abrí **Panel local** (Perfiles/Fichas/Hotspot).
3. Entrá a la pestaña **🛡️ Blindaje**.
4. Tocá **“Detectar mi equipo”** → aparece la lista de equipos del hotspot; el
   que coincide con la IP de tu teléfono sale primero y marcado como
   *“Este teléfono”*. Tocá **Blindar** en ese renglón.
   - Si no aparece, usá **“Agregar MAC/IP”** y pegá la MAC (la ves en
     *IP → Hotspot → Hosts* del MikroTik) o tu IP.
5. Dejá activado **“Blindar automáticamente”** (viene encendido) para que se
   vuelva a blindar solo cuando crees fichas.

Desde ese momento, el portal cautivo no te intercepta: navegás y seguís
trabajando sin consumir una ficha.

---

## 2. Qué hace exactamente en el router

Al blindar, el VPS encola (o la app aplica directo, si está conectada) esto:

```routeros
# 1) Tu equipo queda fuera del portal cautivo
/ip hotspot ip-binding
add address="192.168.10.50" mac-address="AA:BB:CC:DD:EE:FF" type=bypassed \
    comment="StarkGo ADMIN miNombre"

# 2) Queda registrado en una address-list propia (auditoría / reglas propias)
/ip firewall address-list
add list=starkgo_admin address="192.168.10.50" comment="StarkGo ADMIN miNombre"
```

- Se crea **una sola vez** (idempotente): si ya existe, no duplica nada.
- Si el hotspot está apagado, el binding queda **inerte** y no molesta.
- El comentario lleva tu nombre corto (`StarkGo ADMIN ...`) para que lo
  reconozcas entre los demás bindings.

---

## 3. MAC o IP: ¿qué me conviene?

| Blindaje | Aguanta… | Cuándo usarlo |
|---|---|---|
| **MAC** | que el router te dé otra IP (DHCP) | Si tu teléfono usa su **MAC real** (Android: Wi-Fi → *Usar MAC del dispositivo*; iPhone: desactivar *Dirección Wi-Fi privada*) |
| **IP** | que la MAC cambie (MAC aleatoria) | Si tenés **MAC aleatoria** activada (viene así de fábrica en Android 10+ y iOS) |

> 💡 **Lo mejor: blindar las dos.** La función guarda la MAC **y** la IP, y el
> auto-blindaje agrega además la **IP actual** del teléfono cada vez que creás
> fichas. Así queda cubierto en cualquier caso.

⚠️ Con **MAC aleatoria**, la MAC cambia cuando te conectás a otra red: por eso el
auto-blindaje manda la IP actual (no sólo lo guardado).

---

## 4. Dónde se guarda

| Dónde | Qué |
|---|---|
| `config_mikrotik/{uid}.blindajeAdmin` | `{ activo, auto, macs[], ips[] }` (se guarda con `merge`: no pisa el resto de la configuración) |
| Teléfono (SharedPreferences) | Copia local, para poder leerlo **sin internet** cuando estás parado en la red del hotspot |

---

## 5. Cómo se aplica (dos caminos, se intentan los dos)

| Camino | Cuándo | Cuánto tarda |
|---|---|---|
| **Directo al router** (API local, puerto 8728) | Si el panel local está conectado (misma red o por el túnel) | **Instantáneo** |
| **Cola del VPS** (`hotspot-blindar-admin` → `/encolar`) | Siempre (funciona a distancia, por el túnel) | Próximo ciclo del scheduler (**1–5 min**) |

El comando de la cola es idempotente y sólo se encola si cambió algo, así que
reintentar es inofensivo.

---

## 6. Auto-blindaje al crear fichas

Al tocar **“Crear fichas”** (tanto en el panel local como en la pantalla de
generar fichas del VPS), la app ejecuta antes:

```
BlindajeAdminService.autoBlindar()
```

- Si el switch **“Blindar automáticamente”** está apagado, no hace nada.
- Si está prendido, blinda con lo guardado **+ la IP actual** del teléfono.
- Tiene **anti-repetición de 5 minutos** para no encolar el mismo comando con
  cada ficha.
- **Nunca frena la creación de fichas**: si el VPS o el router no responden, se
  registra en el log y la creación sigue igual.

---

## 7. Verificar que quedó bien

En el MikroTik (WinBox / terminal):

```routeros
/ip hotspot ip-binding print where comment~"StarkGo ADMIN"
```

Debe aparecer tu equipo con `type=bypassed`. Si todavía no está, revisá que el
MikroTik esté bajando la cola:

```
http://5.161.88.42:3000/cola/estado?apikey=TU_API_KEY
```

(o en la app: **Config. MikroTik → Cola del VPS → Verificar**).

---

## 8. Quitar el blindaje

- De la lista de la app: tocá la **✕** del chip (deja de re-blindarlo, pero el
  binding del router sigue).
- Del router:

```routeros
/ip hotspot ip-binding remove [find where comment~"StarkGo ADMIN"]
/ip firewall address-list remove [find where list="starkgo_admin"]
```

> ⚠️ Si te quitás el blindaje y estás **detrás del portal**, volvé a blindarte
> antes de seguir (o usá una ficha) para no quedarte sin acceso.

---

## 9. Relacionado

| Tema | Documento |
|---|---|
| Portal de pago para morosos (usa los mismos `ip-binding`) | `PORTAL_MOROSOS.md` |
| Cola con confirmación del VPS | `VPS_INSTRUCCIONES.md` (§5) |
| Túnel WireGuard (para llegar al router a distancia) | `VPN_INSTRUCCIONES.md` |
