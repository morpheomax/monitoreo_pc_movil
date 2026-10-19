# Seguridad

Este sistema puede **matar procesos** de tu equipo desde la red. Tratarlo como una puerta de entrada.

## Riesgos y mitigaciones
| Riesgo | Mitigación |
|---|---|
| Alguien en tu Wi‑Fi se conecta al agente | Emparejamiento con QR + token aleatorio de un solo uso inicial; después token persistente por dispositivo |
| Robo de token | Token por dispositivo, revocable desde el PC |
| Tráfico espiado | TLS con certificado autofirmado generado por agente y fijado (pinning) en el teléfono vía QR |
| Matar un proceso crítico | Lista de protegidos en el agente (no en la app); validar PID + ruta |
| Peticiones repetidas / abuso | Límite de velocidad y registro de acciones |
| Exposición a internet | Por defecto escucha solo en red local o `127.0.0.1` (modo USB) |

## Modo USB
`adb reverse tcp:8765 tcp:8765` hace que el teléfono vea el agente como `localhost:8765`.
Agente en modo USB escucha SOLO en `127.0.0.1`: sin exposición de red.

## Emparejamiento por QR
El QR contiene: IP o nombre del equipo, puerto, token de emparejamiento y huella del certificado.

## Permisos del SO
- Windows: elevar solo el módulo de sensores si es imprescindible.
- macOS: puede pedir permisos de accesibilidad o sudo para ciertos sensores; explicar el porqué en pantalla.

## Registro
Guardar log local de acciones (`kill`, quién, cuándo, resultado).

## Para producto público (más adelante)
- Firmar el instalador de Windows y notarizar la app de Mac.
- Política de privacidad: el sistema no envía datos a servidores externos (salvo clima, que consulta Open-Meteo desde el teléfono).

## Alcance implementado (2026-10-18)

El agente actual solo transmite métricas/procesos; no ejecuta cierres ni otras
acciones. El CLI rechaza interfaces distintas de loopback. El lanzador genera
un token por ejecución y lo muestra para introducirlo en Android; no lo escribe
en archivos ni lo pasa como argumento al proceso hijo. `--token` permite pruebas
manuales y puede quedar en el historial de la terminal si se escribe allí.

QR, TLS, revocación, registros y límites de acciones son diseño pendiente.
No habilitar escucha LAN hasta implementarlos. ADB requiere depuración USB y
autorización explícita del computador en Android.

## Extensión de sesiones 0.2.0

El cliente autenticado puede iniciar/detener sesión, consultar historial y
exportar sus CSV dentro de la carpeta local del agente. No hay API de archivos
arbitrarios ni acciones sobre procesos. Entradas limitadas a 64 KiB; solicitudes
correlacionadas y validadas. Otro agente no puede abrir simultáneamente el mismo
historial. Exportación valida primero el UUID existente y neutraliza nombres de
procesos que pudieran interpretarse como fórmulas en un CSV.

La app solo acepta endpoint USB loopback en esta etapa. Credenciales permanecen
en memoria; el APK release de pruebas todavía usa firma de desarrollo.

## Cierre por PID — agente 0.3.0 / app 0.5.0

Sustituye la limitación de cierres de los apartados históricos anteriores.
Solo localhost/USB. Requiere handshake válido y token también en cada petición
de acción. Sin elevación de permisos ni resolución por nombre de grupo.

- process_prepare valida PID/ruta/creación/propietario y política central; devuelve
  identidad y ticket ligado a esa conexión, máximo 8, 30 s y un solo uso.
- process_terminate exige confirmed=true y modo force booleano; revalida identidad
  y protegidos justo antes de enviar la señal. Límite: un cierre/s por conexión.
- Se bloquean PID de sistema, agente/ancestros, ADB, nombres críticos, ejecutables
  de sistema y procesos ajenos o con identidad ilegible. Si no se puede formar
  la política protectora, monitoreo continúa pero todos los cierres se bloquean.
- psutil terminate/kill incluye comprobación de reutilización del PID. En macOS,
  Finalizar usa SIGTERM y Forzar usa SIGKILL; en Windows ambos terminan el proceso.
- Resultado: terminated, still_running o rechazo explicado. Sin escalado ni
  reenvío automático. Una desconexión no revierte una señal ya confirmada/enviada.
- SQLite process_actions registra requested, signal_sent y resultado, fecha,
  cliente android-usb, PID/ruta/creación y sesión opcional. Sin token ni argumentos.
  La inserción requested debe completarse antes de enviar la señal. Es registro
  local; su exportación/visualización móvil queda pendiente.

No se cierran árboles completos ni grupos por nombre. Cerrar la raíz de una app
puede afectar sus hijos; la confirmación advierte pérdida de trabajo. Los nombres
agrupados solo sirven para presentación. Cambios/errores de identidad obligan a
abrir nuevamente el proceso. Windows físico sigue pendiente de validación.

Referencia de semántica de señales y reutilización: https://psutil.readthedocs.io/stable/index.html
