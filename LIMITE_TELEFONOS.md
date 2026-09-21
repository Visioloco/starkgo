# 📱 Límite de teléfonos por cuenta (máximo 2)

> **Resumen:** cada cuenta (uid) puede tener la app abierta en **2 teléfonos**
> como máximo. El 3.º teléfono ve una pantalla que le permite **liberar** uno
> de los otros dos o **cerrar sesión**.

---

## 1. Dónde se guarda

```
dispositivos/{uid}/equipos/{idDispositivo}
   · propietarioUid : uid dueño de la cuenta
   · nombre         : "Android · 7f3a1c"  (para que el usuario lo reconozca)
   · ultimoUso      : latido (se actualiza al abrir y al volver a la app)
```

- El `idDispositivo` se genera **una vez** por teléfono y se guarda en
  `SharedPreferences` (`sg_dispositivo_id`). Si el usuario borra los datos de
  la app, se genera uno nuevo (por eso existe el botón **Liberar**).

## 2. Cuándo se libera un lugar

| Acción | Qué pasa |
|---|---|
| **Cerrar sesión** en un teléfono | Se borra su documento → libera el lugar al instante |
| Botón **Liberar** de otro teléfono en la pantalla del límite | Se borra ese documento |
| Botón **Usar este teléfono aquí** | Libera el teléfono activo *más antiguo* y entra |
| El teléfono **no abre la app por 7 días** | Su lugar se libera solo (celular perdido/roto) |

## 3. Dónde se controla (código)

| Archivo | Qué hace |
|---|---|
| `lib/services/dispositivo_service.dart` | Toda la lógica: registrar, latido, liberar y verificar |
| `lib/pages/dispositivos/dispositivo_bloqueado_page.dart` | Pantalla "Límite de teléfonos alcanzado" |
| `lib/pages/splash/splash_widget.dart` | Verifica al abrir la app |
| `lib/login/login_widget.dart` | Verifica al iniciar sesión (correo y Google) |
| `lib/pages/home/home_widget.dart` | Verifica/latido al **volver** a la app |
| `lib/auth/firebase_auth/firebase_auth_manager.dart` | Libera el lugar al cerrar sesión |
| `firebase/firestore.rules` | Permisos de `dispositivos/{uid}/equipos/{id}` |

Para cambiar el límite o los días de actividad, se editan las constantes en
`lib/services/dispositivo_service.dart`:

```dart
const int kMaxDispositivosPorCuenta = 2;  // teléfonos por cuenta
const int kDiasActividadDispositivo = 7;  // días para liberar solo
```

## 4. ⚠️ Desplegar las reglas de Firestore

Esta función **necesita** las reglas nuevas de `dispositivos` (si no, Firestore
deniega la lectura/escritura y el límite no funciona):

```bash
cd stark_go
firebase deploy --only firestore:rules
```

## 5. Cómo se ve para el usuario

1. **Teléfono 1** entra normal (ocupa lugar 1).
2. **Teléfono 2** entra normal (ocupa lugar 2).
3. **Teléfono 3** ve: *"Límite de teléfonos alcanzado"* con la lista de los 2
   teléfonos, su último uso, y los botones **Usar este teléfono aquí**,
   **Liberar** y **Cerrar sesión**.
4. Si libera uno, el teléfono liberado **no se cierra al instante**: la próxima
   vez que abra la app se le pedirá liberar otro (o cerrar sesión).

> Nota: es un control del lado de la app (igual que el resto de los controles
> de la app). Si un teléfono pierde su lugar, se le avisa al volver a la app.
