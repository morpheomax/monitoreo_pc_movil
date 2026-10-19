# PC Monitor — instalación y uso

El teléfono Android muestra y gestiona procesos del computador conectado por
USB. **App Android 0.7.0 / agente 0.4.0**. El mismo teléfono sirve para Windows
y macOS; cada computador ejecuta su propio agente y conserva su historial.

## Descargar desde GitHub

Repositorio: [morpheomax/monitoreo_Fitflow](https://github.com/morpheomax/monitoreo_Fitflow).
**Esta aplicación está en `pc-monitor/`**. El monitor de escritorio Fitflow que
aparece en la raíz es otro componente; sus comandos de Playwright no se necesitan
para usar el panel Android.

Elige una forma de obtener PC Monitor:

- **Uso habitual:** abre [los entregables](https://github.com/morpheomax/monitoreo_Fitflow/tree/main/pc-monitor/dist)
  y descarga `pcmonitor-agent-0.4.0.zip` y `pcmonitor-android-0.7.0-arm64.apk`
  (en la página de cada archivo, **Download raw file**). Descomprime el agente
  y continúa desde el paso 1 de esta guía. No hace falta instalar Git.
- **Código completo:** en GitHub usa **Code → Download ZIP** y abre la carpeta
  `monitoreo_Fitflow-main/pc-monitor`, o clona con Git:

```powershell
git clone https://github.com/morpheomax/monitoreo_Fitflow.git
Set-Location .\monitoreo_Fitflow\pc-monitor
```

Desde esa carpeta, coloca `platform-tools` junto a `start.py`. El APK está en
`dist`; para instalarlo desde el clon usa:

```powershell
.\platform-tools\adb.exe install -r .\dist\pcmonitor-android-0.7.0-arm64.apk
```

Prepara primero Python, USB y Platform-Tools según los pasos siguientes.
La [guía Windows desde GitHub](docs/10-ejecutar-windows.md) detalla ambas opciones.
Para actualizar un clon: termina la grabación, detén el agente y ejecuta `git pull
--ff-only` en esta carpeta; si cambió Android, reinstala el APK con `-r`.

## Acceso: ¿cuál es el usuario y la clave?

**Actualmente no se crea una cuenta ni se pide usuario/contraseña.** La credencial
es un **token temporal** generado automáticamente en el computador al iniciar
PC Monitor. No uses tu contraseña de Windows, Mac, Google ni el PIN del teléfono.

**Conexión rápida USB (app 0.7.0 / lanzador 0.4.0):** al iniciar el computador,
la app se abre y recibe el token sin escribirlo. Revisa el **nombre del equipo** y
su **sistema operativo**, y pulsa **Conectar**. Cancelar conserva la conexión
actual. Actualiza tanto el APK como el paquete del agente para usar esta función.
La autorización de depuración USB de Android sigue siendo necesaria por equipo.
La entrega es local, de un solo uso y vence a los 90 segundos; no guarda tokens.
Si vence o la app antigua no la recibe, el token manual continúa disponible.
`--manual-connection` permite iniciar sin abrir el teléfono.

| Dato | Qué escribir / dónde obtenerlo |
|---|---|
| Usuario | No se solicita; no hay un usuario predeterminado. |
| Token del computador | Copiar el valor que aparece junto a **Token:** en la ventana del lanzador del computador. Es la clave temporal de conexión. |
| Dirección del agente | `ws://127.0.0.1:8765`, también mostrada en esa ventana. Normalmente ya está puesta en la app. |
| Grabar sesión | No pide credenciales nuevas: inicia el registro histórico una vez conectado. |

Al abrir **Start Windows.cmd** o **Start Mac.command**, verás un bloque similar:

```text
Abre PC Monitor en Android:
  URL: ws://127.0.0.1:8765
  Token: <TOKEN_GENERADO_EN_ESTA_EJECUCION>
Pulsa Conectar. Mantén esta ventana abierta.
```

El texto entre `< >` es un marcador: **copia el token real de tu pantalla**.
No hay una clave fija de ejemplo para usar a diario. Si reinicias el agente, el
token cambia; si cambias de computador, usa el token de ese computador. Si
cierras/desconectas la app, vuelve a introducirlo cuando lo solicite. El token
no se guarda en archivos del teléfono, del proyecto ni en esta documentación.

Conectar autoriza la consulta y las acciones sobre procesos permitidos de ese
equipo. Grabar una sesión es opcional: el monitoreo en vivo funciona sin grabar.

## Archivos que necesitas

| Archivo | Para qué sirve |
|---|---|
| [APK Android 0.7.0 ARM64](dist/pcmonitor-android-0.7.0-arm64.apk) | Instalar o actualizar PC Monitor en el teléfono. |
| [Agente 0.4.0 Windows y Mac](dist/pcmonitor-agent-0.4.0.zip) | Descomprimir en cada computador; incluye lanzadores e instrucciones para ambos sistemas. |
| [Paquete Windows 0.4.0](dist/pcmonitor-windows-agent-0.4.0.zip) | Alternativa específica de Windows; contiene el mismo agente. Basta elegir uno de los dos ZIP. |
| [SHA256SUMS.txt](dist/SHA256SUMS.txt) | Comprobar integridad de los paquetes entregados. |

**Tu Samsung ya tiene la app 0.7.0 instalada.** Puedes pasar a preparar el otro
computador. Solo repite la instalación Android cuando cambie el APK o uses otro
teléfono. El APK entregado es para **ARM64, Android 7.0/API 24 o posterior**, probado
en Samsung SM-A156M. Otros dispositivos requieren la ABI correspondiente.

El agente necesita **Python 3.11 o posterior con pip** y **Android Platform-Tools**.
La preparación se ha probado en Mac con Python 3.12; se verificaron dependencias
para Windows/Python 3.11, pero el usuario confirmó instalación y funcionamiento en Windows. La conexión rápida nueva requiere validación allí.
No hacen falta Flutter, Android Studio ni emuladores para usar estos paquetes.
La primera preparación del agente necesita internet; el monitoreo funciona localmente.

## 1. Preparar el teléfono — una vez

1. En Samsung abre **Ajustes → Acerca del teléfono → Información de software**.
2. Pulsa **Número de compilación** siete veces para habilitar opciones de
   desarrollador. Si pide el PIN, es el de desbloqueo del teléfono.
3. En **Ajustes → Opciones de desarrollador**, activa **Depuración USB**.
4. Conecta el teléfono con un **cable USB de datos**, desbloquéalo y acepta
   **Permitir depuración USB** para tu computador.
5. Repite la autorización al usar otro computador: autorizar la Mac no autoriza
   Windows automáticamente. Mantén USB conectado durante el uso.

Consulta la [guía oficial para dispositivos físicos](https://developer.android.com/studio/run/device).

## 2. Preparar el computador — elige tu sistema

### Windows

1. Instala [Python para Windows](https://www.python.org/downloads/windows/),
   **3.11 o posterior**, con pip y el lanzador `py`.
2. Descomprime el **ZIP del agente**. Deja la carpeta `PCMonitor` de su interior
   en `C:\PCMonitor`, en disco local.
3. Descarga [Android Platform-Tools](https://developer.android.com/tools/releases/platform-tools)
   para **Windows**. Extrae la carpeta completa `platform-tools` dentro de
   `C:\PCMonitor`; conserva `adb.exe`, sus DLL y demás archivos juntos.
4. Copia el APK entregado dentro de `C:\PCMonitor` si debes instalar/actualizar
   el teléfono desde este equipo.
5. Si ADB no reconoce el Samsung, instala su
   [controlador USB oficial para Windows](https://developer.samsung.com/android-usb-driver).
6. Conecta y autoriza el teléfono. Abre PowerShell en `C:\PCMonitor` y comprueba:

```powershell
py -3 --version
py -3 start.py --check
```

Debes ver **Diagnóstico USB correcto**. Si `py` no existe pero tienes Python
instalado, verifica `python --version` y usa `python start.py --check`.
El lanzador de doble clic admite ambas alternativas.

### macOS

1. Instala [Python para macOS](https://www.python.org/downloads/macos/),
   **3.11 o posterior**, si `python3 --version` no cumple ese mínimo.
2. Descomprime el **ZIP común Windows y Mac**. Deja su carpeta `PCMonitor` en
   `~/Documents/PCMonitor`. También puedes usar este repositorio directamente.
3. Descarga [Android Platform-Tools](https://developer.android.com/tools/releases/platform-tools)
   para **Mac**. Extrae la carpeta completa `platform-tools` junto a `start.py`.
   Si ya tienes el SDK en `~/Library/Android/sdk`, el lanzador también lo busca allí.
4. Copia el APK dentro de esa carpeta si debes instalar/actualizar el teléfono.
5. Conecta y autoriza el teléfono. En Terminal, desde la carpeta `PCMonitor`, comprueba:

```bash
python3 --version
python3 start.py --check
```

Debes ver **Diagnóstico USB correcto**. macOS no requiere el controlador USB
Samsung de Windows, según la [guía de Android](https://developer.android.com/studio/run/device).

### Carpetas esperadas

```text
PCMonitor/
  start.py
  Start Windows.cmd
  Repair USB Windows.cmd
  Start Mac.command                 # incluido en el ZIP común
  LEEME.md                         # incluido en el ZIP común
  LEEME-WINDOWS.md
  LEEME-MAC.md                      # incluido en el ZIP común
  agent/
    server.py
    requirements.txt
    actions/
    history/
    pcmonitor/
    tests/
  platform-tools/                  # descargar para el SO de este computador
    adb.exe                        # Windows, con sus DLL y archivos
    adb                            # Mac, dentro de su propio paquete
  pcmonitor-android-0.7.0-arm64.apk  # copiar si vas a instalar/actualizar Android
```

Los dos ejecutables ADB de la ilustración son alternativas: usa el paquete de tu
sistema. No copies `agent/.venv` de la Mac a Windows. El lanzador crea el entorno
adecuado en cada computador y prepara dependencias automáticamente.

## 3. Instalar o actualizar la app Android

Si PC Monitor 0.7.0 ya está instalado en tu Samsung, continúa al paso 4.
Para otro teléfono compatible o una actualización, con USB autorizado y el APK
copiado junto a `start.py`, ejecuta **una** de estas opciones desde `PCMonitor`:

**Windows — PowerShell:**

```powershell
.\platform-tools\adb.exe devices
.\platform-tools\adb.exe install -r .\pcmonitor-android-0.7.0-arm64.apk
```

**Mac — Terminal:**

```bash
./platform-tools/adb devices
./platform-tools/adb install -r ./pcmonitor-android-0.7.0-arm64.apk
```

Si usas el SDK ya instalado en Mac, sustituye `./platform-tools/adb` por
`"$HOME/Library/Android/sdk/platform-tools/adb"`. `devices` debe listar el teléfono
como **device**, e `install` debe terminar en **Success**. `-r` actualiza la app
conservando sus datos cuando la firma coincide. Con varios dispositivos usa
`adb -s IDENTIFICADOR install -r RUTA_APK`.

Abre **PC Monitor** en el teléfono. Se mostrará en horizontal. El APK entregado
usa firma de desarrollo, igual que la instalación actual; una distribución
pública requerirá firma propia. Si aparece un conflicto de firma, conserva el
mensaje y usa una actualización con la misma firma, sin desinstalar a ciegas.
Referencia de instalación: [Android Debug Bridge](https://developer.android.com/tools/adb#move).

## 4. Conectar y usar — cada vez

1. Conecta el USB y desbloquea/autoriza el teléfono si aparece el aviso.
2. En el computador abre el lanzador de tu sistema:

| Equipo | Doble clic | Alternativa desde la carpeta PCMonitor |
|---|---|---|
| Windows | `Start Windows.cmd` | `py -3 start.py` |
| Mac | `Start Mac.command` | `python3 start.py` |

3. Espera a que termine la preparación y aparezca **PC Monitor escuchando**.
   La primera vez crea `agent/.venv` e instala las dependencias fijadas.
   También configura el reenvío USB. Conserva esa ventana abierta.
4. La app se abre en el teléfono. Revisa **nombre del equipo y sistema** en
   **Conectar por USB**, y pulsa **Conectar**, sin escribir el token.
5. Comprueba **Conectado**, el nombre del equipo y CPU/RAM actualizándose.
   Si no aparece la confirmación, usa el campo manual **Token del computador**
   con el valor de la ventana y `ws://127.0.0.1:8765`. Al reiniciar el agente,
   vuelve a confirmar la conexión enviada; al reconectar solo el cable usa reparar USB.
6. Usa **Gráficas**, **Procesos** y **Sesiones**. No hace falta volver a instalar
   Android para pasar de Mac a Windows.

Si macOS no abre el `.command`, usa la alternativa de Terminal desde la carpeta
del agente. No tienes que activar entornos virtuales a mano.


## 5. Usar las funciones

### Panel horizontal

La app Android 0.7.0 mantiene orientación horizontal sin cambiar la rotación del
sistema. El panel reúne seis métricas, barras por núcleo y gráfica CPU/RAM;
Gráficas muestra CPU/RAM, disco y red simultáneamente. Navegación lateral y
cabecera compacta con conexión, sesión, pantalla activa y desconexión.

Procesos e historial aprovechan columnas con desplazamiento propio. Con el
teclado o texto ampliado se habilita una disposición desplazable para conservar
lectura y acceso. Informes extensos y listas mantienen su desplazamiento.

### Gráficas para comparar el consumo

Coloca el teléfono en **horizontal**; la app mantiene esa orientación en ambos
sentidos. Usa la barra lateral para cambiar entre Panel, Gráficas, Procesos y
Sesiones. Abre **Gráficas**. Cambia entre **1 min** y **5 min**;
toca cualquier gráfica para **ampliarla a pantalla completa**. En esa vista,
toca o desliza sobre la curva para consultar hora y valor. La **X** fija o
**Atrás** vuelven al Panel o Gráficas, según dónde la abriste. Los datos siguen
actualizándose; puedes cambiar 1/5 minutos sin perder la conexión.

- CPU/RAM: escala común fija 0–100 %, para comparar carga y memoria.
- Disco: lectura/escritura con la misma escala automática en bytes/s.
- Red: bajada/subida con la misma escala automática en bytes/s.
- Cada serie muestra valor actual, media y pico de la ventana seleccionada.
- Procesos incluye barras de RAM relativas al mayor grupo visible.

Los datos se acumulan mientras la app está abierta, hasta cinco minutos. Los
huecos no se rellenan con ceros. El historial completo de sesión sigue en el PC.

### Apariencia y navegación

En la cabecera pulsa los iconos **sol** (claro), **luna** (oscuro) o
**A** (seguir el sistema). El modo elegido queda resaltado y Android recuerda
la elección. El control de **Pantalla
activa** solo evita que se apague la pantalla durante la conexión.

Los informes tienen una **X fija** para cerrar. **Atrás** cierra el informe;
desde otras vistas vuelve al Panel y desde Panel ofrece salir. También puedes
usar **⋮ → Salir de la app**. Salir desconecta el teléfono; una grabación activa
continúa en el computador. Para generar su informe usa **Finalizar**; para
detener el agente usa **Ctrl+C** en la ventana del computador.

### Cerrar procesos desde Android

Requiere agente **0.4.0** del paquete actualizado. En **Procesos**, pulsa la **X**
de una tarjeta para abrir sus procesos. Busca el PID y la ruta, pulsa su **X**
y confirma **Finalizar** o **Forzar cierre**. Guarda primero tu trabajo.
La acción afecta al PID seleccionado; no cierra automáticamente todo el grupo.
Los procesos críticos, el agente y ADB aparecen bloqueados con su motivo.

El agente valida token, confirmación, propietario, PID, ruta y creación de nuevo
antes de actuar. La confirmación vence en 30 s y sirve una sola vez. No se
reintentan cierres tras desconectar. Las acciones quedan en SQLite, asociadas
a la sesión si existe. El modo de cierre usa permisos normales, sin elevación.
En macOS Finalizar envía SIGTERM; en Windows termina directamente el proceso.

## 6. Grabar una sesión de trabajo

Pulsa **Grabar sesión** y al terminar **Terminar y ver informe**. Sesiones lista
los últimos 30 informes del equipo. **Exportar CSV al computador** muestra su ruta:
Windows `%LOCALAPPDATA%\PCMonitor`; Mac `~/Library/Application Support/PCMonitor`.
Muestras detalladas por 7 días; después, minutos agregados e informes permanentes.
Si cierras el agente durante la sesión, se recupera como interrumpida en la última
muestra guardada. Desconectar solo el teléfono no termina la sesión.


## 7. Terminar y cerrar

1. Si estás grabando, pulsa **Finalizar** en cabecera o **Terminar y ver informe**
   en Sesiones para generar el informe.
2. Usa **⋮ → Salir de la app** o Desconectar en Android.
3. En el computador pulsa **Ctrl+C** en la ventana del agente. Los lanzadores
   pueden pedir Enter/una tecla para cerrar la ventana después.

Salir o quitar el cable no termina una grabación mientras el agente siga abierto.
Si cierras el agente durante la grabación, al reiniciar se recupera como
**interrumpida**, hasta la última muestra guardada. El historial de cada equipo
permanece allí; no se comparte automáticamente entre Windows y Mac.

## 8. Actualizar y resolver problemas

Para actualizar Android, instala el nuevo APK con `adb install -r`.
Para actualizar el agente, termina primero cualquier grabación, detén el agente
y sustituye sus fuentes por el paquete nuevo. Conserva los datos de usuario:
Windows `%LOCALAPPDATA%\PCMonitor`, Mac `~/Library/Application Support/PCMonitor`.
El lanzador actualiza dependencias si cambian; no copies un entorno virtual de
otro sistema. No necesitas reinstalar Python/Platform-Tools en cada ejecución.

| Síntoma | Qué hacer |
|---|---|
| Me pide usuario o contraseña | PC Monitor solo tiene **Token del computador**. Copia el token del lanzador; no hay cuenta/clave predeterminada. Un PIN del sistema o permiso USB es otro paso. |
| No encuentro el token | Abre el lanzador del equipo que quieres monitorear y conserva su ventana. Espera a que muestre URL y Token. |
| Token inválido | Copia exactamente el de la ejecución actual; al reiniciar el agente cambia. |
| ADB no encontrado | Revisa `platform-tools` junto a `start.py` o usa `--adb RUTA_AL_ADB`. |
| Teléfono unauthorized / no detectado | Desbloquear, aceptar depuración USB, revisar cable de datos/puerto y, en Windows, controlador del fabricante. |
| Hay varios teléfonos | Añade `--serial IDENTIFICADOR` al lanzador. Para instalar APK añade `-s IDENTIFICADOR` a ADB. |
| No conecta tras quitar y volver a poner el cable | Mantén el agente abierto y ejecuta `--repair-usb`; conserva el token y la grabación. |
| La app abre pero no hay datos | Debe ejecutarse el agente en el computador; la app sola no mide ese equipo. Revisa su ventana y la conexión. |
| Cierres deshabilitados | Usa agente 0.4.0, conexión activa y procesos no protegidos. Con un agente antiguo actualiza el ZIP. |
| Otro agente usa el historial / puerto ocupado | Detén la instancia anterior. No borres SQLite para desbloquearlo. |
| APK incompatible | Este archivo es ARM64/API 24+. Compilar otra ABI si corresponde. |
| Conflicto de firma al instalar | Usar APK con la misma firma de la instalación existente; conservar el error para revisarlo. |
| Dependencias no se instalan | Revisar internet, Python 3.11+ con pip y el error de la ventana. |

Ejemplos desde la carpeta del agente:

```powershell
# Windows
py -3 start.py --check
py -3 start.py --repair-usb
py -3 start.py --adb "C:\Android\platform-tools\adb.exe"
```

```bash
# Mac
python3 start.py --check
python3 start.py --repair-usb
python3 start.py --adb "$HOME/Library/Android/sdk/platform-tools/adb"
```

Windows también incluye **Repair USB Windows.cmd**. `--check` diagnostica sin
instalar dependencias ni iniciar el agente; ADB puede iniciar su servicio local.
Para otro puerto: `start.py --port 8766` y URL Android `ws://127.0.0.1:8766`.
Se usa localhost por USB; Wi-Fi/QR/TLS todavía no están habilitados.

## Estado y desarrollo

GitHub Actions: [agente, arranque y paquetes aprobados en Windows y Mac](https://github.com/morpheomax/monitoreo_Fitflow/actions/runs/39186437103)
para la revisión `5ed6537` (24 tests de agente, 9 de arranque y paquetes). El usuario confirmó instalación y funcionamiento básico en Windows; faltan la
conexión rápida nueva y las pruebas prolongadas.

Probado con Mac y Samsung físico: panel horizontal, temas, gráficas, sesiones,
informes/CSV, reconexión y cierre por PID con protección. **La conexión rápida nueva en Windows, sesiones de 1–2 horas y consumo prolongado siguen pendientes**. El paquete
simplifica el arranque, pero todavía requiere Python y Platform-Tools externos.

Los entregables se regeneran desde la raíz de PC Monitor con
`python3 tools/package_release.py` después de compilar el APK. Para verificar un
clon sin Flutter, usa `py -3 tools/package_release.py --check` en Windows o
`python3 tools/package_release.py --check` en Mac: comprueba guías/fuentes de ZIP,
CRC y SHA-256. SDK validado para desarrollo Android: **Flutter 3.47.6**.

Para modificar el código sí se necesitan Flutter/SDK en desarrollo. Consultar
[app/README.md](app/README.md). El APK original se compila en
`app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`; la copia entregable
con nombre estable se prepara en `dist/`. No guardar tokens, contraseñas,
entornos de otros sistemas ni sesiones de navegador en el repositorio.

```bash
# Tests Python (desde la raíz, con dependencias del agente instaladas)
PYTHONPATH=agent agent/.venv/bin/python -m unittest discover -s agent/tests -v
python3 -m unittest discover -s tests -v

# App (desde app/, con SDK de desarrollo)
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

En PowerShell: `agent/.venv/Scripts/python.exe` para el agente y
`$env:PYTHONPATH = 'agent'`. El entorno se prepara con el lanzador; para prepararlo
sin teléfono usa `py -3 -m venv agent/.venv` y
`agent/.venv/Scripts/python.exe -m pip install -r agent/requirements.txt`.
En Mac: `python3 -m venv agent/.venv` y
`agent/.venv/bin/python -m pip install -r agent/requirements.txt`.

| Documento | Contenido |
|---|---|
| [Windows](docs/10-ejecutar-windows.md) | Receta específica para ese equipo |
| [Mac](docs/12-ejecutar-macos.md) | Receta específica para ese equipo |
| [PROGRESS.md](PROGRESS.md) | Avances y evidencia de pruebas |
| [.context/project-memory.md](.context/project-memory.md) | Estado recuperable del proyecto |
| [.context/decisions.md](.context/decisions.md) | Decisiones y tradeoffs |
| [Roadmap](docs/06-roadmap.md) | Fases y criterios de cierre |
| [Mejoras priorizadas](docs/11-mejoras-priorizadas.md) | Propuestas de producto |
| [Arquitectura](docs/01-arquitectura.md) | Componentes y responsabilidades |
| [Protocolo](docs/02-protocolo.md) | Mensajes y capacidades |
| [Sensores](docs/03-sensores.md) | Datos disponibles por plataforma |
| [Seguridad](docs/05-seguridad.md) | Autenticación, permisos y acciones |
| [Sesiones](docs/08-sesiones-e-historial.md) | SQLite, informes y retención |

El código se publica en `pc-monitor/` del repositorio indicado arriba. Al cerrar
trabajo se actualizan README, contexto y PROGRESS; las decisiones se registran aparte.
