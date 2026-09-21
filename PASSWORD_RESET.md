# 🔑 Recuperar contraseña («olvidé mi contraseña»)

Qué hace la app, qué falta configurar en Firebase Console y los textos listos
para pegar en las plantillas de correo.

---

## ⚠️ Estado actual: la consola NO deja editar las plantillas

Al entrar a **Authentication → Templates**, Firebase muestra:

> *Email template updates are currently unavailable for this project. For
> assistance with template changes, contact Firebase Support.*

**Qué significa:** es una restricción **del proyecto** (`starkgo-3671b`), no un
error de configuración tuyo. El editor de plantillas está bloqueado y sólo
Firebase Support puede habilitarlo.

**Qué NO se rompe (importante):** el flujo de recuperación **funciona igual**.
`sendPasswordResetEmail()` (lo que usa la app) manda el correo con el **texto por
defecto de Firebase, en inglés**, y el enlace funciona. O sea: **el operador
puede recuperar su contraseña hoy**; lo único que no se puede es personalizar el
correo (ni traducirlo).

### Camino 1 — Pedirle a Firebase que lo desbloquee (gratis, tarda días)

1. Firebase Console → **Support** (arriba a la derecha) → **Ask a question**
   (o desde Google Cloud Console → *Support*).
2. Pegá este texto:

   > En el proyecto `starkgo-3671b` no puedo editar las plantillas de correo de
   > Authentication (Password reset / Email address verification / Email address
   > change). La consola muestra: “Email template updates are currently
   > unavailable for this project. For assistance with template changes, contact
   > Firebase Support”. Necesito personalizar y traducir al español esas
   > plantillas. ¿Pueden habilitarlo?

3. Cuando te lo habiliten: los textos en español **ya están listos en § 2** de
   este documento — sólo hay que pegarlos.

### Camino 2 — Mandar el correo nosotros desde el VPS (si Support no lo habilita)

No depende del editor de plantillas porque el correo lo enviamos nosotros.
**Plan listo para implementar** (avisame y lo hago):

| Paso | Qué se hace |
|---|---|
| 1 | En el VPS: `POST /auth/recuperar` → genera el enlace con el **Admin SDK**: `admin.auth().generatePasswordResetLink(email, { url: 'https://starkgo-3671b.web.app/reset.html', handleCodeInApp: true })`. Funciona **aunque el editor esté bloqueado** |
| 2 | El VPS manda el correo con **tu HTML en español y tu marca**, vía API REST de un proveedor (Brevo / Resend / SendGrid) con `fetch` → **sin instalar dependencias nuevas en el VPS** |
| 3 | El enlace abre **tu propia página** `https://starkgo-3671b.web.app/reset.html` (la creo yo): pide la contraseña nueva con `verifyPasswordResetCode()` + `confirmPasswordReset()` del JS SDK de Firebase. **Todo en español y en tu dominio** |
| 4 | La app llama primero al VPS y, si no está configurado, **sigue usando el correo de Firebase como hoy** → nunca se rompe nada |

Lo único que hace falta de tu lado: **una API key gratis** de un proveedor
(Brevo: 300 correos/día, verificando tu correo como remitente; Resend: 100/día).
Ojo: el **SMTP settings** de la consola **no** sirve para esto — cambia el
remitente/dominio, pero el **texto sigue siendo el de Firebase**.

Detalles ya verificados en tu repo para este camino:

- `firebase.json` tiene un *rewrite* `** → /index.html`, pero en Firebase
  Hosting **el archivo estático gana** → `/reset.html` se sirve directo, sin
  tocar el deploy. ✅
- `functions/package.json` no tiene librerías de correo → por eso el camino usa
  `fetch` (cero dependencias nuevas). ✅
- `starkgo-3671b.web.app` ya es un dominio autorizado del proyecto. ✅

---

## 1. En la app (ya implementado)

En la pantalla de **Iniciar Sesión**, debajo del campo de contraseña, ahora hay
un enlace azul: **“¿Olvidaste tu contraseña?”**.

| Caso | Qué hace |
|---|---|
| El operador ya escribió su correo en el campo | Le manda el enlace directo a ese correo |
| El correo está vacío o mal escrito | Abre un diálogo *“Recuperar contraseña”* para escribirlo |
| Todo bien | Snackbar verde: *“Te enviamos un enlace a … Revisá también la carpeta de spam.”* |
| Correo inválido | *“Ese correo no es válido.”* |
| No está registrado | *“Ese correo no está registrado en StarkGo.”* |
| Muchos intentos | *“Demasiados intentos. Esperá unos minutos y probá de nuevo.”* |
| Sin internet | *“Sin conexión. Revisá tu internet e intentá otra vez.”* |

Detalles técnicos:

- Usa `FirebaseAuth.sendPasswordResetEmail()`.
- Antes pide el **idioma `es`** (`setLanguageCode('es')`): así la **página web del
  enlace sale en español** y, cuando las plantillas estén desbloqueadas, el correo
  usará automáticamente la **plantilla en español** (§ 2).
- La app **no** revela si el correo existe (ver § 4).

Archivo: `stark_go/lib/login/login_widget.dart`
(`_recuperarContrasena`, `_pedirCorreo`, `_mensajeReset`, `_showOk`).

### Cómo funciona el enlace

1. Llega el correo → el operador toca el enlace.
2. Se abre la página de Firebase (`starkgo-3671b.firebaseapp.com/__/auth/action`)
   con el código de un solo uso.
3. Escribe la **contraseña nueva** y confirma.
4. Vuelve a la app y entra con la contraseña nueva (no hay que reinstalar nada).

El enlace **caduca en 1 hora** y sirve **una sola vez**.

---

## 2. Lo que hay que hacer en Firebase Console (cuando te desbloqueen el editor)

Entrá a **Firebase Console → StarkGo → Authentication → Templates**.

### 2.1 Password reset (la que muestra tu captura)

En el selector de **idioma** del editor, elegí **Español (es)** si está
disponible; si no aparece, editá la plantilla por defecto (la misma que ves) y
pegá el texto de abajo. **No cambies `%LINK%`, `%EMAIL%` ni `%APP_NAME%`**:
son los datos que reemplaza Firebase.

| Campo | Valor |
|---|---|
| **Sender name** | `StarkGo` |
| **From** | dejalo como está (`noreply@starkgo-3671b.firebaseapp.com`) o usá *Customize domain* con tu dominio (ver § 4) |
| **Reply to** | *(opcional)* tu correo de soporte, ej. `soporte@tudominio.com` |
| **Subject** | `Restablecé tu contraseña de StarkGo` |

**Message:**

```html
<p>Hola,</p>
<p>Recibimos un pedido para restablecer la contraseña de tu cuenta de StarkGo (%EMAIL%).</p>
<p>Entrá a este enlace para crear una contraseña nueva:</p>
<p><a href="%LINK%">Crear contraseña nueva</a></p>
<p>Si no fuiste vos, podés ignorar este correo: tu contraseña actual sigue funcionando.</p>
<p>Gracias,</p>
<p>El equipo de StarkGo</p>
```

### 2.2 (Opcional, ya que estás ahí) Verificación de correo

Mismo procedimiento, plantilla **Email address verification**:

- **Subject:** `Verificá tu correo en StarkGo`

```html
<p>Hola,</p>
<p>Confirmá que este correo (%EMAIL%) es tuyo para activar tu cuenta de StarkGo.</p>
<p><a href="%LINK%">Verificar mi correo</a></p>
<p>Si no creaste esta cuenta, ignorá este mensaje.</p>
<p>Gracias,</p>
<p>El equipo de StarkGo</p>
```

### 2.3 (Opcional) Cambio de correo

Plantilla **Email address change** (usa también `%NEW_EMAIL%`):

- **Subject:** `Confirmá tu nuevo correo en StarkGo`

```html
<p>Hola,</p>
<p>Pediste cambiar el correo de tu cuenta de StarkGo de %EMAIL% a %NEW_EMAIL%.</p>
<p><a href="%LINK%">Confirmar el cambio</a></p>
<p>Si no fuiste vos, ignorá este correo.</p>
<p>Gracias,</p>
<p>El equipo de StarkGo</p>
```

> 💡 La app **hoy no envía** correos de verificación ni de cambio de correo
> (no están conectados en el flujo), pero la plantilla queda lista en español
> para cuando los actives.

---

## 3. Probar que funciona (3 minutos)

1. En la app, tocá **“¿Olvidaste tu contraseña?”** y poné el correo de un
   operador de prueba.
2. Revisá la bandeja **(y spam)** de ese correo: tiene que llegar
   *“Restablecé tu contraseña de StarkGo”* con el botón *Crear contraseña nueva*.
3. Abrilo desde el **teléfono**, escribí una contraseña nueva y después entrá a
   la app con esa contraseña.

Si el correo **no llega**:

| Síntoma | Causa probable |
|---|---|
| No llega nada y la app dice que sí lo envió | **Email enumeration protection** activo: si el correo no existe, Firebase no manda nada (a propósito). Probá con un correo que **sí** exista en la lista de usuarios |
| Llega a **spam** | Normal con `@<proyecto>.firebaseapp.com`. Solución: *Customize domain* con tu dominio + los registros SPF/DKIM que te da Firebase (§ 4) |
| El correo llega **en inglés** | Falta cargar la plantilla en **Español (es)**… o el editor de plantillas está **bloqueado** en tu proyecto → ver la sección ⚠️ al inicio del documento |
| “Ese correo no es válido” | El correo escrito tiene un error de tipeo |

---

## 4. Notas importantes

- **Privacidad (anti-enumeración):** por diseño la app responde siempre
  *“Te enviamos un enlace…”*, aunque el correo no exista, para no revelar qué
  cuentas están registradas. Si tenés *Email enumeration protection* activo,
  Firebase tampoco devuelve error.
- **Dominio propio (recomendado):** en *Templates → Customize domain* podés usar
  `noreply@tudominio.com`. Requiere verificar el dominio en Firebase y cargar
  los registros **SPF y DKIM** en tu DNS: mejora muchísimo la entrega (deja de
  caer en spam) y se ve más profesional.
- **Dominios autorizados:** si algún día usás una **página propia** para el
  enlace, ese dominio debe estar en *Authentication → Settings → Authorized
  domains*.
- **No toques `%LINK%`**: es el enlace con el código de un solo uso.
- **Contraseña mínima:** Firebase exige **6 caracteres** como mínimo (la app
  también lo valida al iniciar sesión).

---

## 5. Opcional (avanzado): que el enlace vuelva a la app

Hoy el enlace abre la página de Firebase (funciona perfecto y es lo más simple).
Si algún día querés que el enlace abra **directamente tu pantalla** para cambiar
la contraseña dentro de la app, se hace así:

1. En la app:
   `sendPasswordResetEmail(email: correo, actionCodeSettings: ActionCodeSettings(url: 'https://starkgo-3671b.web.app/reset', handleCodeInApp: true, androidPackageName: 'com.starkgo.net', iOSBundleId: '...'))`.
2. Una página propia en **Firebase Hosting** (`/reset`) que lea el `oobCode`.
3. Que la app reciba el `oobCode` y llame a
   `FirebaseAuth.verifyPasswordResetCode()` + `confirmPasswordReset()`.

---

## 6. Relacionado

| Tema | Documento |
|---|---|
| Publicar la web (Firebase Hosting) | `DEPLOY_WEB.md` |
| Límite de 2 teléfonos por cuenta (mismo login) | `LIMITE_TELEFONOS.md` |
| Registro de operadores | `stark_go/lib/pages/Registro/registro_widget.dart` |

