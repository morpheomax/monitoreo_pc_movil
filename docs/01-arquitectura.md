# Arquitectura

## Flujo implementado (agente 0.3.0 / app 0.6.0)

```text
Windows / macOS                         Android físico
start.py + agente Python   ← USB →      app Flutter
  ADB reverse                           MonitorController (dart:io)
  WebSocket v1 en loopback               Panel / Gráficas / Procesos / Sesiones
  muestreador compartido                reconexión + detección de datos detenidos
    métricas cada 1 s                   pantalla activa opcional
    procesos cada 3 s
  SQLite → informe → CSV
```

El teléfono no ejecuta Python. El APK es el mismo para Windows y Mac; las
capacidades del agente controlan las funciones disponibles. No hay emuladores
ni acceso desde internet. Wi-Fi/QR/TLS y distribución pública son posteriores.

## Agente

- `start.py`: prepara un entorno por equipo, encuentra ADB y autoriza el flujo
  según el dispositivo USB. `--repair-usb` restaura el reenvío sin reiniciar.
- `pcmonitor/metrics.py`: interfaz común de métricas y agrupación. psutil cubre
  datos base; adaptadores avanzados de temperatura/presión siguen pendientes.
  En Mac los helpers se agrupan por el bundle exterior `.app` cuando su ruta es legible.
- `actions/processes.py`: política común de protegidos/propietario, validación
  PID+exe+creación, tickets por conexión (30 s/un uso), rate limit y señales.
  Cada intento de cierre se registra en process_actions de SQLite, con sesión opcional.
- `server.py`: valida `hello`, anuncia capacidades y atiende comandos de sesión;
  un único muestreador alimenta a todos los clientes y al historial.
- `history/store.py`: SQLite, informes, recuperación, retención y exportación.
- `pcmonitor/instance_lock.py`: bloqueo del directorio de datos entre procesos
  (fcntl en macOS, msvcrt en Windows), liberado por el SO al terminar el proceso.

Sin clientes ni sesión no se captura. Con una sesión activa se sigue capturando
sin teléfono. Cada muestra se confirma en SQLite; un cierre abrupto puede perder
la muestra en curso, pero no inventa datos posteriores. Al reiniciar se genera
informe interrumpido hasta la última muestra guardada.

El muestreo y las escrituras son síncronos y pequeños en el bucle del agente.
Antes de escalar sensores o clientes se debe volver a medir; solo trasladar
trabajo a otro hilo si hay evidencia de bloqueo y conservar el estado de muestreo.

## App

- `main.dart`: arranque y tema.
- `connection/monitor_controller.dart`: estado observable con ChangeNotifier,
  autenticación, mensajes, solicitudes correlacionadas y conexión cancelable.
- `models/metric_history.dart`: hasta cinco minutos/650 muestras recibidas,
  con timestamps y huecos explícitos.
- `widgets/metric_chart.dart`: curvas con escalas, media/pico y selección táctil;
  variantes compacta y ampliada ajustadas a altura disponible.
- `widgets/landscape_shell.dart`: navegación lateral y cabecera; orientación
  Android sensorLandscape. SafeArea conserva márgenes del sistema/cámara.
- `screens/expanded_chart_page.dart`: ruta ampliada con X fija/Atrás, selector
  1/5 min, mismo controlador/historial en vivo y fallback accesible desplazable.
- `screens/dashboard_page.dart`: panel adaptable, gráficas, búsqueda/orden de procesos,
  sesiones e informe; sin reglas específicas del SO para interpretar métricas.
- Canal Android `pcmonitor/panel`: bandera de ventana KEEP_SCREEN_ON mientras
  esté conectada, el usuario lo habilite y la app esté visible. Sin servicio en
  segundo plano ni wake lock de CPU.

Reintentos con espera creciente hasta 15 s. Credenciales rechazadas y protocolo
inválido detienen reintentos. Apertura y handshake limitados a 8 s; sin métricas
por 8 s se cierra el transporte y se reintenta. La cancelación invalida callbacks
anteriores. Datos en vivo se retiran al perder conexión; token solo en memoria.

Se mantiene D-005: Flutter estándar, sin Riverpod/Bloc ni paquete WebSocket extra.
El detalle/cierre móvil vive en process_details_sheet.dart; sugerencias sigue pendiente.

## Datos y permisos

Historial en `%LOCALAPPDATA%\PCMonitor` (Windows) o
`~/Library/Application Support/PCMonitor` (Mac). Los CSV se crean allí desde la
acción del teléfono; no hay acceso genérico a archivos del computador.
El agente trabaja con permisos del usuario, sin elevación de la app completa.

Sensores no disponibles: `null` y motivo. Una temperatura alta no se presenta
como prueba de estrangulamiento térmico. El cierre por PID pasa por actions/: token, confirmación, protegido,
propietario e identidad PID/ruta/creación se validan antes de enviar la señal.
Nunca se resuelve una acción usando el nombre agrupado de una aplicación.

## Presupuesto y aceptación

Objetivo del agente en reposo: <1 % CPU y <60 MB RAM. Medición breve con Android
y SQLite activos: 1.0 % CPU y 18.88 MiB RSS en 20 s, en esta Mac; falta una prueba
prolongada y Windows. No confundir consumo del agente con CPU total del equipo.
