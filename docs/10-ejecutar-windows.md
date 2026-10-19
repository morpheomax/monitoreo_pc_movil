# PC Monitor en Windows — instalación y uso

App Android **0.6.0**, agente **0.3.0**. El mismo teléfono sirve para Windows y
Mac. Windows físico sigue pendiente de validación; las pruebas registradas son
Mac + Samsung. No necesitas Flutter, Android Studio ni un emulador para usarlo.

## 0. Obtener el proyecto desde GitHub

PC Monitor Android se encuentra en **pc-monitor/** del repositorio
[morpheomax/monitoreo_Fitflow](https://github.com/morpheomax/monitoreo_Fitflow).
El programa Fitflow de la raíz tiene otra instalación; aquí usarás `start.py`
dentro de `pc-monitor`, sin instalar sus dependencias de CRM/Playwright.

### Opción A — paquetes listos, sin Git

1. Abre [pc-monitor/dist](https://github.com/morpheomax/monitoreo_Fitflow/tree/main/pc-monitor/dist).
2. Descarga `pcmonitor-agent-0.3.0.zip`, `pcmonitor-android-0.6.0-arm64.apk` y
   `SHA256SUMS.txt`. En cada archivo usa **Download raw file**, no Guardar página.
3. Extrae el ZIP para obtener `C:\PCMonitor` y copia el APK junto a `start.py`.
4. Continúa en **1. Preparar Windows**; no vuelvas a descargar el mismo ZIP.

### Opción B — clonar el código y poder actualizar con Git

Instala [Git para Windows](https://git-scm.com/downloads/win). Desde PowerShell,
en la carpeta donde quieras guardar el repositorio:

```powershell
git clone https://github.com/morpheomax/monitoreo_Fitflow.git
Set-Location .\monitoreo_Fitflow\pc-monitor
```

Si el repositorio es privado, inicia sesión en GitHub cuando Git lo solicite;
esa autorización sirve para descargar código, **no es la credencial de PC Monitor**.
También puedes usar **Code → Download ZIP**, extraerlo y abrir
`monitoreo_Fitflow-main\pc-monitor` sin instalar Git.

En estas variantes trabaja desde esa carpeta en lugar de `C:\PCMonitor` y coloca
`platform-tools` junto a `start.py`. No necesitas descomprimir además el ZIP del
agente. El APK ya está dentro de `dist`; el comando del paso 3 será:

```powershell
.\platform-tools\adb.exe install -r .\dist\pcmonitor-android-0.6.0-arm64.apk
```

## Credencial de conexión: no hay usuario ni contraseña

PC Monitor pide **Token del computador**. El lanzador genera ese token al iniciar
el agente y lo muestra junto a la URL. No hay cuenta que registrar, usuario
predeterminado ni clave de Windows que introducir en la app.

```text
URL: ws://127.0.0.1:8765
Token: <COPIAR_EL_TOKEN_REAL_DE_LA_VENTANA>
```

El marcador de arriba no es una clave real. El token cambia al reiniciar el
agente. Usa el token del equipo que quieres monitorear; no lo guardes en README
ni en archivos compartidos. **Grabar sesión** es opcional y solo inicia historial.

## 1. Preparar Windows — una vez

1. Instala [Python para Windows](https://www.python.org/downloads/windows/),
   **3.11 o posterior**, con pip y el lanzador `py`.
2. Descomprime `pcmonitor-agent-0.3.0.zip` (común Windows/Mac) o
   `pcmonitor-windows-agent-0.3.0.zip`. Basta uno. Deja la carpeta **PCMonitor**
   que viene dentro en `C:\PCMonitor`, en disco local.
3. Descarga [Android Platform-Tools para Windows](https://developer.android.com/tools/releases/platform-tools).
4. Extrae su carpeta completa `platform-tools` dentro de `C:\PCMonitor`.
   Debe existir `C:\PCMonitor\platform-tools\adb.exe`; conserva las DLL y demás
   archivos. El lanzador lo detecta sin configurar PATH.
5. Copia `pcmonitor-android-0.6.0-arm64.apk` junto a `start.py` si debes instalar
   o actualizar Android. El APK se entrega por separado del ZIP del agente.
6. Si Windows no reconoce el Samsung, instala el
   [controlador USB oficial](https://developer.samsung.com/android-usb-driver).

```text
C:\PCMonitor\
  Start Windows.cmd
  Repair USB Windows.cmd
  start.py
  LEEME-WINDOWS.md
  agent\
    server.py
    requirements.txt
    actions\
    history\
    pcmonitor\
  platform-tools\
    adb.exe
    ...
  pcmonitor-android-0.6.0-arm64.apk
```

No copies `.venv` desde la Mac. Se crea un entorno Windows automáticamente; la
primera ejecución necesita internet para preparar las dependencias Python.

## 2. Preparar el teléfono y autorizar este Windows

1. En Samsung: **Ajustes → Acerca del teléfono → Información de software →
   Número de compilación**, pulsar siete veces. Si pide PIN, es el del teléfono.
2. En **Opciones de desarrollador**, activa **Depuración USB**.
3. Conecta un **cable de datos**, desbloquea el teléfono y acepta **Permitir
   depuración USB** para este Windows. Autorizar la Mac no autoriza este equipo.
4. En PowerShell, desde `C:\PCMonitor`, ejecuta:

```powershell
py -3 --version
py -3 start.py --check
```

Debe aparecer **Diagnóstico USB correcto**. Si solo tienes `python`, comprueba
`python --version` (3.11+) y usa `python start.py --check`; el lanzador admite esa
alternativa. [Preparación USB oficial](https://developer.android.com/studio/run/device).

## 3. Instalar Android — omitir si ya tienes 0.6.0

El APK entregado es ARM64/API 24+; está probado en Samsung SM-A156M. En PowerShell,
con USB autorizado y desde `C:\PCMonitor`:

```powershell
.\platform-tools\adb.exe devices
.\platform-tools\adb.exe install -r .\pcmonitor-android-0.6.0-arm64.apk
```

El dispositivo debe figurar como **device** y la instalación terminar en
**Success**. `-r` actualiza conservando datos cuando la firma coincide.
Con varios dispositivos: `adb -s IDENTIFICADOR install -r RUTA_APK`.
El APK actual usa firma de desarrollo. Conflicto de firma: conserva el error y
usa un APK de la misma firma; no desinstales a ciegas.
[Referencia ADB](https://developer.android.com/tools/adb#move).

## 4. Conectar — cada vez

1. Conecta y desbloquea el teléfono; acepta permisos si se solicitan.
2. Abre **Start Windows.cmd** o ejecuta `py -3 start.py` en PowerShell.
3. Espera la preparación automática y el mensaje **PC Monitor escuchando**.
   Conserva abierta la ventana; ahí están URL y token.
4. Abre PC Monitor en Android, en horizontal. En **Panel**, copia el valor de
   **Token:** al campo **Token del computador**. URL normal: `ws://127.0.0.1:8765`.
5. Pulsa **Conectar**. Comprueba nombre del Windows, **Conectado** y CPU/RAM
   actualizándose. No se solicita usuario ni contraseña adicional.

Al reiniciar el agente, copia el token nuevo. La app no guarda credenciales en
archivos. No necesitas reinstalar Android para cambiar de computador.

## 5. Funciones y grabación opcional

- **Panel / Gráficas:** métricas en vivo y curvas CPU/RAM, disco/red; ventanas 1/5 min.
- **Procesos:** X de tarjeta → elegir PID/ruta → X individual → confirmar
  Finalizar o Forzar cierre. Los protegidos muestran el motivo. En Windows,
  ambos modos terminan el proceso; guarda el trabajo antes de confirmar.
- **Sol/luna/A:** tema claro, oscuro o del sistema. Se recuerda la elección.
- **Grabar sesión:** guarda métricas en el computador; puedes trabajar durante
  horas. El agente debe permanecer ejecutándose, aunque desconectes el teléfono.
- **Finalizar / Terminar y ver informe:** termina la grabación y muestra su informe.
- **Exportar CSV al computador:** muestra dónde quedaron los archivos.

```text
%LOCALAPPDATA%\PCMonitor\
  sessions.sqlite3
  exports\IDENTIFICADOR_DE_SESION\
    samples.csv
    minutes.csv
    top_apps.csv
    report.json
```

Detalle reciente por 7 días; después, minutos agregados e informes conservados.
La auditoría de cierres vive en SQLite; aún no se exporta en los CSV. Cada equipo
conserva sus datos, sin sincronización automática con la Mac.

## 6. Terminar y cerrar

1. Si grabas, pulsa Finalizar para generar el informe.
2. En Android usa **⋮ → Salir de la app** o Desconectar.
3. En la ventana Windows pulsa **Ctrl+C** y luego una tecla si el lanzador lo pide.

Salir de Android no termina una grabación activa. Si detienes el agente durante
la grabación, al reiniciar se recupera como interrumpida hasta la última muestra.

## 7. Problemas frecuentes y actualización

```powershell
py -3 start.py --check
py -3 start.py --repair-usb
py -3 start.py --adb "C:\Android\platform-tools\adb.exe"
```

| Síntoma | Acción |
|---|---|
| No encuentro usuario/clave | No existen como cuenta: usa el token del lanzador. |
| No encuentro el token | Abrir Start Windows.cmd y esperar URL/Token; conservar esa ventana. |
| Token rechazado | Usar el de la ejecución actual; cambia al reiniciar el agente. |
| Python no encontrado | Instalar Python 3.11+ con pip/lanzador; abrir terminal nueva. |
| ADB no encontrado | Revisar `platform-tools\adb.exe` y sus archivos junto a `start.py`. |
| Teléfono unauthorized / no detectado | Desbloquear, autorizar, revisar cable/puerto y controlador USB. |
| Varios dispositivos | Usar `py -3 start.py --serial IDENTIFICADOR`. |
| Reconectando tras quitar el cable | Volver a conectar; abrir **Repair USB Windows.cmd** sin cerrar el agente. Conserva token y grabación. |
| Cierre deshabilitado | Actualizar agente a 0.3.0; confirmar conexión y que el proceso no esté protegido. |
| Otro agente usa el historial | Detener la instancia anterior; no borrar SQLite. |
| Puerto ocupado | Detener la otra instancia o usar `--port 8766` y cambiar la URL Android a ese puerto. |

Para actualizar el agente: terminar grabación, detenerlo y sustituir sus fuentes
por el paquete nuevo. Conservar `%LOCALAPPDATA%\PCMonitor`. Android se actualiza
con el nuevo APK y `adb install -r`; Python/Platform-Tools no se reinstalan cada vez.
Wi-Fi, QR, sugerencias y sensores avanzados siguen pendientes. Lo ausente se
muestra como —. Esta guía no sustituye la validación física pendiente de Windows.

## Gráficas ampliadas — app 0.6.0

Toca la gráfica del Panel o cualquiera de Gráficas para ampliarla. Mantiene datos
en vivo y selector 1/5 min; toca/desliza para consultar valores. X fija o Atrás
vuelven a la vista anterior sin reconectar. El agente 0.3.0 sigue siendo compatible.

## Actualizar desde GitHub

Si clonaste, termina la grabación y detén el agente antes de ejecutar desde
`pc-monitor`:

```powershell
git pull --ff-only
```

Si descargaste ZIP, obtén la nueva entrega y sustituye sus fuentes con el agente
detenido. Conserva `%LOCALAPPDATA%\PCMonitor` y tu carpeta `platform-tools`.
No copies `.venv` de otro computador. Reinstala Android con `-r` cuando cambie
el APK. Después abre **Start Windows.cmd** y usa el nuevo token del agente.
