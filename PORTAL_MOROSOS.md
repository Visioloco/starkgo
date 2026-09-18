# Portal de pago para clientes en mora (hotspot solo para esa IP)

> 🔗 **Túnel / VPN:** eso vive en **`CONFIGURAR_VPN.md`** (y en la app, en la
> pantalla *Configurar VPN*). Este documento es sólo del portal de morosos.
>
Guía para que, cuando suspendas a un cliente, **esa IP** (solo esa) quede
"cautiva" y al abrir el navegador vea el **login/hotspot con tu información de
pago** en lugar de simplemente "sin internet".

> ⚠️ **No rompe nada existente**: esta función está **apagada por defecto**.
> Mientras `portalMorosos` esté en `false`, la app se comporta exactamente
> igual que hoy (bloqueo total por lista `morosos`). Solo cuando lo enciendes
> la app **además** quita/restaura el "bypass" del hotspot para ese cliente.

---

## Qué hace la app cuando activas la función

| Evento | Antes (sin cambio) | Con `portalMorosos: true` |
|---|---|---|
| Suspender (mora) | Agrega IP a `morosos` (drop total) + WhatsApp | Igual **+** quita el `ip hotspot ip-binding` (bypass) de esa IP **+** corta su sesión de hotspot activa → queda cautiva y ve el portal **al instante** |
| Reactivar (activo) | Saca IP de `morosos` + WhatsApp | Igual **+** vuelve a crear el `ip-binding type=bypassed` → navega normal sin portal |

> ✅ **Blindaje automático (siempre):** cada vez que creás un cliente o lo
> reactivás (botón *Activo* en Detalle Cliente, o registrás un pago), la app
> encola el `ip-binding type=bypassed` de su IP **aunque el portal esté
> apagado**. Si el hotspot no está configurado el binding queda inerte y no
> molesta a nadie; si está encendido, evita que el cliente vea el portal
> cautivo. (Antes esto sólo pasaba con `portalMorosos: true`.)

Los comandos llegan por la **misma cola del VPS** (el script/scheduler del
MikroTik que ya tienes), así que no necesitas tocar el scheduler. La cola ahora
**se confirma**: si el router no aplica los comandos, el VPS los reenvía solo
(ver `VPS_INSTRUCCIONES.md` §5) y podés ver el estado en la app →
**Config. MikroTik → "Cola del VPS" → Verificar**.

---

## 📱 (NUEVO) Editar el portal desde cualquier lugar — página alojada en el VPS

Ya quedó implementado en la app. En el **editor de diseño del hotspot**
(MikroTik → Diseño del hotspot) aparece la tarjeta **"Portal de pago (VPS)"**:

1. Diseñas el HTML igual que siempre (título, valor, WhatsApp, medios de pago).
2. Tocas **"Publicar en portal VPS"** → se guarda en el VPS
   (Firestore `portal_vps/<apikey>`) y se abre la **vista previa real** con la
   URL pública (exactamente como la verá el moroso).
3. Tocas **"Ver publicado"** cuando quieras revisarla sin volver a subir nada.

URL pública de tu página:
`http://5.161.88.42/portal/<apikey>/<archivo>`

Endpoints nuevos en el VPS:
- `POST /hotspot/pagina` (guardar HTML, con apikey)
- `GET /portal/:apikey/:archivo` (servir la página, público)

### Marcadores dinámicos (nombre y saldo automáticos)

El VPS rellena automáticamente estos marcadores cuando la página se abre con
`?ip=...`:

| Marcador | Qué muestra |
|---|---|
| `{{nombre}}` | Nombre del cliente |
| `{{saldo}}` | Valor del plan a pagar (`planValor`) |
| `{{plan}}` | Nombre del plan |
| `{{ip}}` | IP del cliente |
| `{{fecha}}` | Fecha del día |

Ejemplo dentro del HTML que diseñas:

```html
<h2>Hola {{nombre}}</h2>
<p>Tu servicio está suspendido.</p>
<p>Valor a pagar: <b>{{saldo}}</b></p>
<p>Plan: {{plan}}</p>
```

Para que el VPS sepa **qué cliente** es, el redirect del hotspot debe enviar
la IP del que abre el navegador (RouterOS reemplaza `$(ip)`):

```html
<meta http-equiv="refresh"
  content="0; url=http://5.161.88.42/portal/TU_APIKEY/login.html?ip=$(ip)">
```

Para que el moroso vea **ESA** página (en vez del login del router), el
`login.html` del MikroTik debe redirigir a esa URL. Puedes publicarlo una sola
vez con el botón "Publicar en el router" (estando en la red local) o pegarlo
por terminal. Ejemplo de `login.html` mínimo:

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh"
      content="0; url=http://5.161.88.42/portal/TU_APIKEY/login.html">
  </head>
  <body><p>Redirigiendo…</p></body>
</html>
```

Y agrega el VPS al **walled garden** del hotspot para que la página cargue sin
que el cliente esté autenticado:

```routeros
/ip hotspot walled-garden add dst-host=5.161.88.42
```

> ⚠️ En la página del VPS **no uses variables de MikroTik** (`$(username)`,
> `$(ip)`, etc.): esas solo se reemplazan cuando el propio router sirve el
> archivo. Para el portal de pago usa HTML estático (texto, logo, WhatsApp).

---

## 🔧 Lo que se configura en el MikroTik (una sola vez), explicado fácil

Hay **3 piezas** y cada una hace una cosa distinta. Piensa en un edificio:

1. **El hotspot** = la "portería" que intercepta al que no está autorizado y le
   muestra una página.
2. **El walled garden** = una **lista blanca**: "aunque no esté autorizado,
   déjalo entrar SOLO a esta dirección (tu VPS)".
3. **La regla de firewall de morosos** = la **malla de seguridad** que corta el
   internet real del moroso. Se conserva para que no navegue nada más.

### Paso A — La lista blanca (walled garden) para que cargue tu página

El moroso está bloqueado, pero la página de pago vive en tu VPS
(`5.161.88.42`). Sin esta línea, el MikroTik no dejaría cargar esa página a un
cliente no autenticado. Con ella, el moroso SOLO puede abrir tu portal:

```routeros
/ip hotspot walled-garden add dst-host=5.161.88.42
```

> Analogía: le das al moroso una "tarjeta" que solo abre la puerta de tu página
> de pago, ninguna otra.

### Paso B — El `login.html` del hotspot redirige a tu página del VPS

El hotspot siempre muestra su propio `login.html`. Para que el cliente vea **TU
página del VPS** (y no el login de fichas), ese `login.html` no debe tener el
diseño: debe ser un **aviso que redirige** en 0 segundos a tu URL:

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh"
      content="0; url=http://5.161.88.42/portal/TU_APIKEY/login.html">
  </head>
  <body><p>Redirigiendo…</p></body>
</html>
```

> Sustituye `TU_APIKEY` por tu clave (la ves en Config MikroTik → vpsApiKey, o
> en la URL que te muestra "Ver publicado").

Este archivo se sube **una sola vez** al router (botón "Publicar en el router"
estando en la red local, o por FTP/Winbox a la carpeta `hotspot/`). Después, el
diseño se edita en el VPS sin volver a tocar el router.

> 💡 Si luego quieres nombre/saldo automáticos, agrega `?ip=$(ip)` al final de
> la URL (RouterOS lo reemplaza por la IP del cliente):
> `.../portal/TU_APIKEY/login.html?ip=$(ip)`

### Paso C — Conserva la regla que corta a los morosos

Esta regla ya la tienes y **no se quita**: es la que impide que el moroso
navegue cualquier otra cosa. Solo hay que asegurarse de que exista **y que esté
ARRIBA** de los `accept` (y de cualquier `fasttrack`) de `chain=forward`: si
queda al final de la cadena, el moroso sigue navegando. Este comando la deja
arriba de todo y no duplica (borra la vieja primero):

```routeros
:if ([:len [/ip firewall filter find where comment="Bloqueo a Morosos"]] > 0) do={ /ip firewall filter remove [find where comment="Bloqueo a Morosos"] }
/ip firewall filter add chain=forward src-address-list=morosos action=drop place-before=0 comment="Bloqueo a Morosos"
```

> ¿Por qué puede ver el portal si está "drop total"? Porque el portal viaja al
> propio router/VPS por una ruta distinta (no pasa por `chain=forward`): el
> walled garden (Paso A) es quien se lo permite.

### Paso D — (no olvidar) Clientes al día con "bypassed"

Para que el portal **NO** le salga a los que están al día, cada cliente normal
debe tener su `ip hotspot ip-binding type=bypassed`. Ver el **Paso 3** de esta
guía (la app lo agrega/quita automáticamente al activar/suspender).

---

## Paso 0 — Habilitar la función en la app
1. Abre **Configuración → MikroTik**.
2. En el **Paso 3 — Regla de bloqueo a morosos**, activa el interruptor
   **"Portal de pago para morosos"**.
3. Presiona **Guardar configuración**.

> Internamente guarda `portalMorosos: true` en `config_mikrotik/{tuUid}`.

(Equivalente manual: Firestore → colección `config_mikrotik` → doc de tu uid →
agregar campo `portalMorosos: true`.)

---

## Paso 1 — Crear el Hotspot en el MikroTik (una sola vez)

Abre **New Terminal** en Winbox y ejecuta:

```routeros
# Perfil con tus páginas (la carpeta hotspot/ donde la app ya sube el login)
/ip hotspot profile add name=perfil-pago html-directory=hotspot

# Servidor hotspot sobre la interfaz donde están los clientes (tu bridge/LAN)
/ip hotspot add name=hs-pago interface=bridge-local profile=perfil-pago
```

> Reemplaza `bridge-local` por la interfaz real de tus clientes.
> Cuando el hotspot queda activo, **solo** se muestran el portal a las IPs que
> NO tengan `ip-binding type=bypassed`. Por eso el Paso 3 es obligatorio.

---

## Paso 2 — La página del portal = información de pago

El hotspot muestra el archivo `hotspot/login.html` del MikroTik. En la app ya
tienes el **editor de diseño del hotspot** que sube esas páginas por FTP
(`hotspot_ftp_service.dart`).

Ajusta el **login** para que, en vez de pedir usuario/clave, muestre:

- "Servicio suspendido por falta de pago"
- Valor a pagar y medios (Nequi/Daviplata/efectivo)
- WhatsApp de soporte
- Indicación de que al pagar se reactiva en minutos

Sube la página y verifica abriendo `http://IP_DEL_MIKROTIK` desde un equipo de
prueba sin binding.

---

## Paso 3 — Clientes al día: binding "bypassed" (obligatorio)

Cuando el hotspot está activo, **cada cliente al día necesita su
`ip-binding type=bypassed`** para que el portal NO le salga. La app lo crea
automáticamente cada vez que activas un cliente (y lo quita al suspenderlo),
pero **los clientes que ya existen** debes darlos de alta una vez.

Desde el New Terminal:

```routeros
# Quita bindings viejos (opcional, si ya habías probado)
/ip hotspot ip-binding remove [find]

# Crea bypass para todos los leases DHCP activos (una sola vez)
:foreach i in=[/ip dhcp-server lease find] do={
  :local ip [/ip dhcp-server lease get $i address]
  :if ([:len [/ip hotspot ip-binding find where address="$ip"]] = 0) do={
    /ip hotspot ip-binding add address=$ip type=bypassed comment="al dia"
  }
}
```

Si tus clientes no usan DHCP (IPs fijas), agrega manualmente cada IP:

```routeros
/ip hotspot ip-binding add address=192.168.88.50 type=bypassed comment="al dia"
```

> Puedes repetir ese loop cuando agregues clientes nuevos, o simplemente
> reactivar al cliente desde la app (la app crea el bypass solo).

---

## Paso 4 — Mantén la regla de firewall de morosos

Conserva la regla que ya configuraste (drop para `morosos`), **arriba de los
`accept`** de la cadena (si no, no corta):

```routeros
:if ([:len [/ip firewall filter find where comment="Bloqueo a Morosos"]] > 0) do={ /ip firewall filter remove [find where comment="Bloqueo a Morosos"] }
/ip firewall filter add chain=forward src-address-list=morosos action=drop place-before=0 comment="Bloqueo a Morosos"
```

Así el moroso **no navega nada**, pero igual puede cargar el portal porque ese
tráfico va al propio router (no pasa por `chain=forward`).

---

## Paso 5 — Probar el flujo completo

1. Suspende a un cliente de prueba (botón **Suspender/notificar**).
2. Espera el ciclo del scheduler (el MikroTik consulta la cola del VPS).
3. Verifica en Winbox:
   - `IP → Firewall → Address List`: la IP está en `morosos`.
   - `IP → Hotspot → IP Bindings`: **ya no existe** el binding `bypassed` de esa IP.
   - `IP → Hotspot → Active`: la sesión de esa IP se cortó (así el portal aparece
     al instante, sin esperar a que caduque).
4. En el equipo del cliente, abre el navegador → debe aparecer tu portal de pago.
5. Reactiva al cliente → la IP sale de `morosos` y **vuelve a aparecer** el
   binding `bypassed` → navega normal sin portal.

---

## Notas importantes

- **El portal aparece al abrir el navegador (HTTP)**. Si el moroso no abre el
  navegador, no lo ve → el WhatsApp de suspensión sigue siendo clave.
- **HTTPS**: el portal clásico de MikroTik redirige tráfico HTTP. El login y el
  WhatsApp deben llevar el mensaje/medio de pago para que no dependas de HTTPS.
- **Rendimiento**: no pongas TODA la navegación de clientes normales detrás del
  hotspot; usa siempre el `bypassed` para ellos (Paso 3).
- Si algún día quieres desactivar todo: apaga el switch en Config MikroTik y
  guarda. La app volverá a solo "bloquear/desbloquear" sin tocar el hotspot.

---

## Redesplegar

1. Backend (nuevos comandos de la cola): en `functions/` ejecuta
   `firebase deploy` (o el comando que uses para tu Express/Cloud Run).
2. App: recompila e instala con `flutter run` / nuevo build.
