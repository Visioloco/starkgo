# 🌐 Publicar la app en WEB (responsiva)

> La app está preparada para usarse en el navegador (PC, tablet y celular) y se
> publica en **Firebase Hosting** en un solo comando. En pantallas anchas se
> muestra centrada en una columna tipo teléfono; en el celular, a pantalla
> completa.

---

## 1. Publicar (un comando)

```powershell
cd C:\Users\FABI\Downloads\stark_go
.\deploy_web.ps1 -ConReglas
```

- `.\deploy_web.ps1` → compila la web y la publica.
- `.\deploy_web.ps1 -ConReglas` → además sube las **reglas de Firestore**.
- `.\deploy_web.ps1 -SoloBuild` → sólo compila en `stark_go\build\web`.

La web queda en:

- **https://starkgo-3671b.web.app**
- **https://starkgo-3671b.firebaseapp.com**

### Requisito: cuenta con permiso

El proyecto `starkgo-3671b` sólo lo puede publicar la **cuenta dueña**
(la que creó el proyecto en Firebase). Si el deploy dice
*"Failed to get Firebase project"*:

```powershell
firebase login:list     # ver con qué cuenta estás
firebase login:add      # entrar con la cuenta dueña del proyecto
firebase use starkgo-3671b
.\deploy_web.ps1 -ConReglas
```

> También podés dar permiso a otra cuenta desde Firebase Console →
> ⚙️ *Usuarios y permisos* → agregar como **Editor/Propietario**.

## 2. Reglas de Firestore (¡importante!)

Varias funciones nuevas viven en colecciones que necesitan reglas:

| Colección | Para qué |
|---|---|
| `dispositivos/{uid}/equipos/{id}` | límite de **2 teléfonos** por cuenta |
| `configuracion_local/{uid}` | recordar la conexión local del MikroTik |
| `config_mikrotik/{uid}` | datos del router, red local y puerta de enlace |

Subilas con `.\deploy_web.ps1 -ConReglas`, o sólo las reglas:

```powershell
firebase deploy --only firestore:rules --project starkgo-3671b
```

## 3. Qué funciona en la web y qué no

| Función | Web | Nota |
|---|---|---|
| Login (correo/contraseña), registro, membresía | ✅ | |
| Login con Google | ⚠️ | Ver punto 4 |
| Clientes, planes, PPPoE, equipos, starlinks | ✅ | |
| Informes, finanzas, facturación, pagos, consumo | ✅ | |
| MikroTik: datos, API Key, scheduler, scripts, cola del VPS | ✅ | |
| Red local / puerta de enlace / netmap / VPN (túnel) | ✅ | El túnel en sí sólo se puede *encender* desde el teléfono |
| Portal de morosos (publicar en el VPS) | ✅ | |
| **Conexión Local (Modo Local)**, perfiles/fichas locales | ❌ | Necesita sockets/API local y FTP: sólo desde la app |
| **Editor del portal** (FTP + borradores en el equipo) | ❌ | Sólo desde la app |
| Notificaciones locales | ❌ | No existen en el navegador |

Las funciones ❌ muestran una pantalla explicando que se usan desde el teléfono
(`lib/widgets/sin_soporte_web.dart`).

## 4. Login con Google en web (opcional)

1. Firebase Console → *Authentication* → *Sign-in method* → **Google**: copiá el
   **Client ID web**.
2. Pegalo en `stark_go/web/index.html` (hay un comentario listo para eso):
   ```html
   <meta name="google-signin-client_id" content="XXXX.apps.googleusercontent.com">
   ```
3. Firebase Console → *Authentication* → *Settings* → **Dominios autorizados**:
   `starkgo-3671b.web.app` ya viene; agregá tu dominio propio si usás uno.
4. Volvé a publicar (`.\deploy_web.ps1`).

## 5. Cómo se ve (responsive)

- **Celular / ventana angosta (< 700 px):** igual que la app, a pantalla completa.
- **Tablet (700–1099 px):** columna centrada de 520 px.
- **PC / pantalla grande (≥ 1100 px):** columna centrada de 460 px con esquinas
  redondeadas y fondo oscuro.
- Se agregó `<meta name="viewport">` al `index.html` (sin eso, los navegadores
  de celular usaban un ancho de 980 px y se veía todo diminuto).

El marco está en `stark_go/lib/main.dart` (`_marcoResponsive`): si querés que en
PC se vea a ancho completo, alcanza con cambiar los valores de esa función.

## 6. Archivos que se usan

| Archivo | Qué hace |
|---|---|
| `deploy_web.ps1` | compila + publica |
| `firebase.json` (raíz) | hosting (`stark_go/build/web`) + reglas de Firestore |
| `stark_go/web/index.html` | viewport, splash web, Client ID de Google |
| `stark_go/lib/main.dart` | marco responsive + arranque web-safe (sin App Check/notificaciones locales) |
| `stark_go/lib/widgets/sin_soporte_web.dart` | cartel "no disponible en web" |

> 💡 Recordá que el teléfono (APK) y la web comparten la MISMA base de datos y el
> mismo login. Lo que hacés en la web se ve en el teléfono y viceversa.
