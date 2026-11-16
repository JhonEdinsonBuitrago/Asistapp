# AsistApp

Aplicación móvil para el **control de asistencia a clases universitarias** mediante códigos QR dinámicos. Docentes y estudiantes usan la misma app, con vistas distintas según su rol.

> Proyecto académico desarrollado por **Jhon Edinson Buitrago Gonzalez y Juan David Plaza Florez**

## Contenido

- [Credenciales de prueba](#credenciales-de-prueba)
- [Funcionalidades implementadas](#funcionalidades-implementadas)
- [Cómo funciona la asistencia con QR](#cómo-funciona-la-asistencia-con-qr)
- [Recorrido sugerido para evaluar](#recorrido-sugerido-para-evaluar)
- [Datos de ejemplo y datos reales](#datos-de-ejemplo-y-datos-reales)
- [Funcionalidades por mejorar](#funcionalidades-por-mejorar)
- [Tecnologías](#tecnologías)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Instalación y ejecución](#instalación-y-ejecución)
- [Reglas de seguridad de Firestore](#reglas-de-seguridad-de-firestore)
- [Autor](#autor)

---

## Credenciales de prueba

Estas cuentas ya están registradas en la aplicación:

| Rol            | Correo                      | Contraseña    |
| -------------- | --------------------------- | ------------- |
| **Estudiante** | `jhon.buitrago@udla.edu.co` | `Jhon@162006` |
| **Docente**    | `patiño@udla.edu.co`        | `Patiño1234`  |

**Notas:**

- En la pantalla de **Iniciar sesión**, elige la pestaña que corresponda al rol (**Estudiante** o **Docente**). Si la cuenta no coincide con la pestaña, la app lo avisa.
- También puedes **crear una cuenta nueva**: en la bienvenida pulsa **Crear cuenta nueva** y elige el rol. Los estudiantes escriben además su código estudiantil. No se exige verificación del correo.
- Son cuentas **solo para la evaluación del proyecto**.

---

## Funcionalidades implementadas

### Comunes

- Pantalla de bienvenida, registro con rol, inicio de sesión y recuperación de contraseña por correo.
- La sesión se mantiene abierta y la app redirige al panel según el rol.
- Editar perfil (nombre y teléfono), cambiar contraseña (enlace por correo) y cerrar sesión.

### Estudiante

- **Inicio:** asistencia global, cursos en los que está matriculado y filtro de cursos en riesgo.
- **Detalle del curso:** balance de asistencia con gráfico circular, faltas permitidas y tarjeta de **clase en progreso** en tiempo real.
- **Registro de asistencia** escaneando el **QR dinámico** con la cámara o escribiendo el **código de 6 dígitos**. Funciona **sin conexión**: el registro se guarda en el dispositivo y se envía cuando vuelve la red.
- **Estados del registro:** guardado, enviado, confirmado, en revisión y no validado, cada uno con su pantalla.
- **Historial de asistencia** por curso, con filtros (presentes, faltas, justificadas, en proceso).
- **Justificación de faltas** (plazo de 72 horas): el estudiante envía el motivo y sigue el estado de la solicitud.
- Notificaciones y perfil.

### Docente

- **Inicio:** resumen general, cursos con filtros e indicador de justificaciones por revisar.
- **Crear curso** (activo o borrador) y **matricular estudiantes** buscándolos en el directorio o pegando una lista de códigos o correos.
- **Configurar la sesión de asistencia:** duración (5, 10, 15 minutos o personalizada) y frecuencia de cambio del código (15 o 60 segundos).
- **QR en vivo:** cronómetro, código que cambia, modo de pantalla ampliada para proyectar, extender 3 minutos, presentes y pendientes, y lista de registros en vivo.
- **Validación automática** de los registros y **revisión manual** (aprobar o rechazar los dudosos).
- **Estadísticas del curso:** tasa de asistencia, distribución de faltas, tendencia semanal y monitoreo de estudiantes en riesgo.
- **Detalle de asistencia de cada estudiante**, con historial por clase.
- **Revisión de justificaciones** (aprobar o rechazar con una nota).
- Notificaciones y perfil.

---

## Cómo funciona la asistencia con QR

1. El docente **inicia la sesión** (requiere conexión una sola vez). Se genera una clave secreta de esa sesión.
2. El QR y el código de 6 dígitos se **calculan en el dispositivo del docente** con el algoritmo TOTP (el mismo principio de Google Authenticator) y cambian cada 15 o 60 segundos. No necesitan internet.
3. El estudiante escanea el QR o escribe el código. El registro se **guarda en su dispositivo** y se envía cuando hay conexión.
4. La **app del docente valida** cada registro con la clave de la sesión: comprueba el código, el horario y la hora del escaneo.
5. Resultado de cada registro:
   - **Confirmado:** el código y la hora son correctos.
   - **En revisión:** algo es dudoso (código manual sin conexión, hora que no coincide, sincronización después de 24 horas o un mismo teléfono con varios estudiantes). El docente decide.
   - **Rechazado:** código inválido, fuera del horario o QR vencido.

Un QR no garantiza por sí solo la presencia física: si un compañero envía el código en el momento, no se puede detectar. Por eso existen la revisión manual y las señales de dispositivo compartido.

---

## Recorrido sugerido para evaluar

> Para probar docente y estudiante a la vez, usa una **ventana normal** del navegador para uno y una **ventana de incógnito** para el otro, o un celular. Dos pestañas normales comparten la misma sesión.

**Ver las vistas rápidamente:** los cursos de ejemplo del inicio del docente (_Arquitectura de Software_, etc.) muestran estadísticas, listas de estudiantes y detalles completos con datos de ejemplo. Los cursos de ejemplo no registran asistencia real.

**Flujo completo con datos reales:**

1. Inicia sesión como **Docente** y pulsa **Crear curso**. Escribe un nombre (por ejemplo, "Redes de Computadores") y pulsa **Crear e inicializar curso**.
2. En la tarjeta del curso nuevo, abre el menú **⋮ → Detalle del curso → Añadir Alumno**. Busca al estudiante de prueba, pulsa **+ Agregar** y **Confirmar y matricular en sección**.
3. Vuelve al curso, pulsa **Activar Toma de Asistencia** y **Iniciar sesión de asistencia**. Aparecen el QR y el código de 6 dígitos.
4. En la otra ventana, inicia sesión como **Estudiante**, desliza hacia abajo en el inicio para actualizar y abre el curso. Pulsa **Registrar Asistencia Ahora** y escanea el QR con la cámara o escribe el **código de 6 dígitos**.
5. En la vista del docente aumenta el número de registros y el estudiante ve **Asistencia confirmada**.
6. **Faltas y justificaciones:** el docente finaliza la sesión e inicia otra **sin** que el estudiante registre. El estudiante abre el **Historial** del curso y pulsa **Justificar**. El docente abre **Justificaciones** (menú ⋮ del curso) y la aprueba.
7. El docente puede consultar **Estadísticas** y el **detalle de cada estudiante** desde el curso.

---

## Datos de ejemplo y datos reales

| Parte                                                                             | Origen                                                            |
| --------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Registro, inicio de sesión, perfiles, recuperación de contraseña                  | **Reales** (Firebase)                                             |
| Cursos creados por el docente, matrícula, sesiones, QR, registros, validación     | **Reales** (Firestore)                                            |
| Justificaciones                                                                   | **Reales** (Firestore)                                            |
| Historial, estadísticas y detalle por estudiante de los cursos **que crees**      | **Reales**, calculados con las sesiones y registros               |
| Cursos de ejemplo del inicio, sus listas de estudiantes, estadísticas e historial | **De ejemplo** (generados)                                        |
| Inicio del estudiante sin cursos reales                                           | **De ejemplo**, con un aviso visible                              |
| Notificaciones de estudiante y docente                                            | **De ejemplo** (la tarjeta "Sesión en curso" del docente es real) |
| Programa, ciclo, departamento y reglamento                                        | **De ejemplo**                                                    |

---

## Funcionalidades por mejorar

### Seguridad y cuentas

- Cualquier persona puede registrarse como **docente**: falta restringirlo (lista de docentes autorizados o rol de administrador).
- No hay **verificación del correo** (por ejemplo, con un código enviado al correo) ni restricción al dominio institucional.
- Las rutas no comprueban el rol por dirección: en la versión web, un usuario podría abrir una ruta de otro rol.
- No hay verificación en dos pasos (2FA).
- Los correos de recuperación de contraseña pueden ser bloqueados por los filtros del correo institucional.

### Asistencia

- La validación de los registros la hace la **app del docente** al abrir la sesión, porque no hay servidor (se evitó Cloud Functions por su costo). Un servidor la haría automática.
- La hora de un escaneo hecho sin conexión no se puede comprobar. Se mitiga con revisión manual, plazo de 24 horas y detección de dispositivo compartido.
- No hay baliza Bluetooth ni geolocalización.
- La pantalla del docente no se mantiene encendida automáticamente durante la clase.
- En la versión web, los registros pendientes sin conexión solo se conservan mientras la pestaña esté abierta.
- No se pueden programar sesiones por adelantado.

### Cursos y matrícula

- Los cursos reales no guardan **horario ni aula**, por lo que no hay "próximas sesiones" en ellos.
- No se puede editar un curso en borrador ni retirar estudiantes de un curso desde la interfaz.
- Si un estudiante se matricula a mitad del ciclo, las estadísticas del docente cuentan todas las sesiones anteriores.
- El directorio de estudiantes para matricular está limitado a 500.

### Justificaciones

- No se pueden **adjuntar archivos** (requiere Firebase Storage): se escribe el motivo y el número de referencia del comprobante.
- Las faltas justificadas siguen contando para el límite del 20 %.

### Notificaciones y reportes

- Las notificaciones no son reales ni llegan al teléfono (_push_), y el estado de leído no se guarda.
- Exportar el informe y generar certificados no crean archivos PDF ni Excel: copian el contenido como texto.
- No hay foto de perfil.

### Otros

- Los textos de **soporte**, **términos y reglamento** son provisionales.
- La app se desarrolló y probó principalmente en **navegador web (Edge)**. Falta configurar los permisos de cámara para iOS y probar en más dispositivos.
- No hay pruebas automáticas.
- Las lecturas de Firestore crecen con el número de sesiones; a futuro conviene guardar contadores en el curso.

---

## Tecnologías

- **Flutter** y Dart (versión del SDK en `pubspec.yaml`)
- **Firebase Authentication** (correo y contraseña) y **Cloud Firestore**, en el plan gratuito (Spark)
- **Riverpod** (estado) y **go_router** (navegación)
- `mobile_scanner` (lectura de QR), `qr_flutter` (generación de QR), `crypto` (códigos TOTP) y `shared_preferences` (almacenamiento local)

---

## Estructura del proyecto

```text
lib/
├── main.dart
├── firebase_options.dart        # configuración de Firebase (generada)
├── app/                         # rutas (go_router)
├── core/                        # tema, widgets y servicios compartidos
└── features/
    ├── auth/                    # bienvenida, inicio de sesión, registro, recuperar contraseña
    ├── student/                 # pantallas y datos del estudiante
    ├── teacher/                 # pantallas y datos del docente
    ├── attendance/              # QR, códigos TOTP, registros y validación
    └── justifications/          # justificación de faltas
```

---

## Instalación y ejecución

**Requisitos:** Flutter SDK, un editor (VS Code o Android Studio) y un navegador (Edge o Chrome) o un dispositivo Android.

```bash
git clone https://github.com/JhonEdinsonBuitrago/Asistapp.git
cd asistapp
flutter pub get
flutter run -d edge          # o -d chrome, o un dispositivo Android
```

Si el navegador no abre, usa `flutter run -d web-server --web-port 5000` y abre `http://localhost:5000`.

**Notas:**

- El repositorio incluye `lib/firebase_options.dart`, que apunta al proyecto de Firebase de desarrollo (`asistapp-dev`). **No hace falta configurar nada** para probar la app con las credenciales de arriba.
- En Windows, Flutter necesita el **Modo de desarrollador** activado para compilar los plugins de Firebase.
- Para el escáner con cámara en el navegador se necesita una cámara y que la app corra en `localhost`. Sin cámara se puede usar el código de 6 dígitos.
- En Android, `minSdk` debe ser 23 o superior.

**Para usar un proyecto de Firebase propio:**

1. Crea un proyecto en [Firebase](https://console.firebase.google.com) y habilita **Authentication** con correo y contraseña.
2. Crea una base de datos **Cloud Firestore** y publica las reglas de `firestore.rules`.
3. Ejecuta `flutterfire configure` para regenerar `lib/firebase_options.dart`.

---

## Reglas de seguridad de Firestore

Las reglas están en [`firestore.rules`](firestore.rules). Controlan, entre otras cosas, que:

- Cada usuario lea y edite solo su perfil, y que nadie pueda cambiar su rol.
- Cada docente vea y administre solo sus cursos.
- Un estudiante solo pueda registrar asistencia si está **matriculado** en el curso.
- Solo el docente de una sesión pueda leer su clave y cambiar el resultado de la validación.
- Las justificaciones se envíen dentro del plazo de 72 horas y las decida únicamente el docente del curso.

---

## Autores

**Jhon Edinson Buitrago Gonzalez y Juan David Plaza Florez**
