# PC Monitor en Mac — instalación y uso

App Android **0.6.0**, agente **0.3.0**. El computador ejecuta el agente; el
Android muestra los datos por USB. Probado en Mac + Samsung SM-A156M físico.
El mismo APK sirve para conectarlo después a Windows.

## Obtener desde GitHub

La aplicación Android está en `pc-monitor/` del repositorio
https://github.com/morpheomax/monitoreo_Fitflow . Puedes descargar los paquetes
versionados de esa carpeta `dist`, usar Code → Download ZIP o clonar:

```bash
git clone https://github.com/morpheomax/monitoreo_Fitflow.git
cd monitoreo_Fitflow/pc-monitor
```

Si clonas, coloca `platform-tools` junto a `start.py` y usa el APK de `dist/` al
instalarlo. El monitor de escritorio de la raíz mantiene su instalación propia.

## Acceso: token temporal, sin usuario/contraseña

Abre **Start Mac.command** o ejecuta `python3 start.py`. El lanzador genera y
muestra una URL y **Token:**. Copia ese token al campo **Token del computador**
en Android. No uses la contraseña del Mac, Apple ID ni PIN del teléfono.
No hay cuenta o clave predeterminada; Grabar sesión solo inicia el historial.

```text
URL: ws://127.0.0.1:8765
Token: <EL_TOKEN_REAL_DE_LA_VENTANA>
```

El marcador no es una credencial. Reiniciar el agente cambia el token. La app
no lo guarda en archivos; introdúcelo cuando lo solicite. No registres tokens
reales en README, capturas compartidas ni archivos del proyecto.

## 1. Preparar el Mac — una vez

1. Comprueba `python3 --version`. Si no tienes **3.11 o posterior con pip**,
   instala [Python para macOS](https://www.python.org/downloads/macos/).
2. Descomprime `pcmonitor-agent-0.3.0.zip`. Deja su carpeta `PCMonitor` en
   `~/Documents/PCMonitor`. También puedes usar el repositorio directamente.
3. Descarga [Android Platform-Tools para Mac](https://developer.android.com/tools/releases/platform-tools).
   Extrae la carpeta completa `platform-tools` junto a `start.py`. Si ya tienes
   el SDK en `~/Library/Android/sdk`, el lanzador también busca ADB allí.
4. Copia `pcmonitor-android-0.6.0-arm64.apk` junto a `start.py` si debes instalar
   o actualizar Android. Se entrega separado del ZIP del agente.

```text
PCMonitor/
  Start Mac.command
  start.py
  LEEME.md
  LEEME-MAC.md
  agent/
    server.py
    requirements.txt
    actions/
    history/
    pcmonitor/
  platform-tools/
    adb
    ...
  pcmonitor-android-0.6.0-arm64.apk
```

Python y Platform-Tools se preparan en el computador. El teléfono solo necesita
el APK y depuración USB; Flutter, Android Studio y emuladores no son necesarios
para usarlo. El lanzador crea `agent/.venv` y prepara sus dependencias; no copies
ese entorno a Windows. La primera preparación necesita internet.

## 2. Preparar Android y autorizar el Mac

1. Samsung: **Ajustes → Acerca del teléfono → Información de software → Número
   de compilación**, siete pulsaciones. Si pide PIN, usa el del teléfono.
2. Activa **Depuración USB** en **Opciones de desarrollador**.
3. Conecta un cable de datos, desbloquea y acepta **Permitir depuración USB**
   para este Mac. Tendrás que autorizar Windows por separado al cambiar de equipo.
4. En Terminal, desde la carpeta `PCMonitor`, ejecuta:

```bash
python3 start.py --check
```

Debe aparecer **Diagnóstico USB correcto**. macOS no requiere el controlador
USB del fabricante que puede necesitar Windows. [Preparación oficial Android](https://developer.android.com/studio/run/device).

## 3. Instalar Android — omitir si ya tienes 0.6.0

APK ARM64/API 24+, probado en Samsung SM-A156M. Desde la carpeta `PCMonitor`,
con el APK copiado y el teléfono autorizado:

```bash
./platform-tools/adb devices
./platform-tools/adb install -r ./pcmonitor-android-0.6.0-arm64.apk
```

Si usas el SDK existente:

```bash
"$HOME/Library/Android/sdk/platform-tools/adb" install -r ./pcmonitor-android-0.6.0-arm64.apk
```

`devices` debe mostrar **device** y la instalación **Success**. `-r` conserva
datos al actualizar con la misma firma. Con varios teléfonos usa `-s IDENTIFICADOR`
antes de `install`. El APK entregado usa firma de desarrollo; si hay conflicto
de firma, conserva el error y usa una actualización con la misma firma.
[Referencia ADB](https://developer.android.com/tools/adb#move).

## 4. Conectar — cada vez

1. Conecta/desbloquea el teléfono y acepta depuración si se solicita.
2. Abre **Start Mac.command** o, desde Terminal en `PCMonitor`, ejecuta:

```bash
python3 start.py
```

3. Espera a **PC Monitor escuchando** y conserva la ventana. El lanzador prepara
   el entorno y el reenvío USB automáticamente; no actives entornos a mano.
4. Abre PC Monitor en el teléfono, en horizontal. Copia el **Token:** mostrado
   en el Mac; dirección normal `ws://127.0.0.1:8765`. Pulsa **Conectar**.
5. Comprueba **Conectado**, el nombre del Mac y CPU/RAM actualizándose.

Si macOS no abre el `.command`, usa la alternativa de Terminal desde la carpeta
del agente. Al reiniciar, usa el nuevo token. Al cambiar de equipo no reinstales
Android: desconecta la app y conecta con el token de ese equipo.

## 5. Uso y datos

Panel y Gráficas muestran métricas; Procesos permite buscar/ordenar y cerrar:
X de tarjeta → PID/ruta → X individual → confirmar Finalizar o Forzar cierre.
Guarda el trabajo antes de confirmar. Los protegidos no permiten cierre.
Finalizar envía SIGTERM; Forzar cierre usa SIGKILL, con confirmación explícita.

Grabar sesión es opcional; al terminar usa Finalizar / Terminar y ver informe.
La grabación sigue sin teléfono mientras el agente esté abierto. Exportar CSV al
computador muestra la carpeta dentro de:

```text
~/Library/Application Support/PCMonitor/
  sessions.sqlite3
  exports/IDENTIFICADOR_DE_SESION/
    samples.csv
    minutes.csv
    top_apps.csv
    report.json
```

Detalle de 7 días; después, agregados por minuto e informes conservados. La
auditoría de cierres está en SQLite y todavía no se exporta en CSV. El historial
no se sincroniza automáticamente con el de Windows.

## 6. Cerrar, reparar y actualizar

1. Si grabas, termina la sesión para generar informe.
2. En Android: **⋮ → Salir de la app** o Desconectar.
3. En el Mac: **Ctrl+C** en la ventana del agente, y Enter si el lanzador lo pide.

Cerrar Android no termina una grabación. Si se detiene el agente durante ella,
se recuperará como interrumpida hasta la última muestra guardada al reiniciar.

Para diagnosticar/reparar USB, desde la carpeta del agente:

```bash
python3 start.py --check
python3 start.py --repair-usb
python3 start.py --adb "$HOME/Library/Android/sdk/platform-tools/adb"
```

`--repair-usb` conserva agente/token/grabación; úsalo tras reconectar el cable.
Token rechazado: copiar el de la ejecución actual. ADB no encontrado: revisar
`platform-tools` o pasar `--adb`. No hay usuario/contraseña que recuperar.

Para actualizar: terminar grabación, detener agente, sustituir fuentes por el
paquete nuevo y conservar `~/Library/Application Support/PCMonitor`. Actualiza
Android con `adb install -r` del APK nuevo. No reinstales Python/Platform-Tools
cada vez. Wi-Fi/QR, sugerencias y pruebas prolongadas siguen pendientes.

## Gráficas ampliadas — app 0.6.0

Toca una gráfica para ampliarla con datos en vivo, consulta táctil y selector
1/5 min. X fija o Atrás regresan al origen sin desconectar. Agente sin cambios.
