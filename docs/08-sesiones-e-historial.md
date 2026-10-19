# Sesiones e historial — 0.2.0

Una sesión es un período de trabajo monitoreado. Sin sesión se transmite en vivo
sin persistir muestras. Con sesión, el agente conserva datos aunque Android se
desconecte. Una sesión por equipo; los historiales Mac y Windows son independientes.

## Implementación y ubicación

`agent/history/store.py` usa SQLite estándar, transacciones por muestra, claves
foráneas y WAL. Un bloqueo del directorio evita que dos agentes recuperen o
modifiquen el mismo historial simultáneamente. No requiere permisos elevados.

- Windows: `%LOCALAPPDATA%\PCMonitor\sessions.sqlite3`.
- macOS: `~/Library/Application Support/PCMonitor/sessions.sqlite3`.
- CLI del agente: `--data-dir` permite elegir otra carpeta local.

## Modelo implementado

| Tabla | Contenido |
|---|---|
| `sessions` | UUID, inicio, fin, host, SO e informe JSON permanente |
| `samples` | Timestamp real, CPU, RAM, swap, tasas de disco/red, indicador de muestreo de procesos y payload completo de métricas |
| `process_samples` | Top 20 grupos por memoria: nombre, CPU y RAM cada 3 s |
| `minute_samples` | Conteo, promedios y picos de muestras antiguas agrupadas por minuto |

El payload conserva durante el detalle reciente las métricas de cada muestra,
incluidos datos por núcleo y sensores que estén disponibles. El informe vive
separado del detalle para no perderlo cuando se aplica retención.
Todavía no hay tablas de acciones ni apps cerradas: llegarán con gestión de procesos.

## Informe

- CPU y RAM: promedio de muestras válidas, pico y primera hora en que se registró.
- Duración real entre inicio y fin; número de muestras, sin rellenar huecos.
- Top apps: suma de valores de los grupos observados / número de capturas de
  procesos; un grupo fuera del top aporta cero en esa captura. Es una estimación
  limitada al top 20, no una atribución exhaustiva de consumo.
- CPU de procesos puede superar 100 % al sumar varios núcleos.
- Sin muestras válidas, resultados `null`; no se inventan promedios o picos.
- Throttling y memoria liberada: `null` con motivo hasta disponer de medición
  de estrangulamiento real y de acciones. Una temperatura alta no prueba throttling.

Al reiniciar un agente que tenía sesión activa, se genera un informe marcado
interrumpido hasta la última muestra confirmada. No se cuenta tiempo apagado
como tiempo monitoreado. La app muestra esa condición en el historial.

## Retención

- Muestras detalladas de sesiones terminadas: 7 días, luego se convierten a minutos.
- Minutos completos: conteo, promedio y pico CPU/RAM, promedios swap y tasas disco/red.
- `process_samples`: se elimina su detalle antiguo tras calcular el informe.
- Informes y minutos agregados: sin vencimiento en este incremento.
- Se aplica al arrancar el agente y al terminar sesión. No elimina muestras de
  una sesión que todavía está activa.
- Preferencias de retención y borrado desde la app quedan pendientes.

## CSV desde Android

La acción **Exportar CSV al computador** crea en `exports/UUID`:

- `samples.csv`: columnas numéricas y payload JSON de detalle reciente.
- `minutes.csv`: agregados antiguos (solo cabeceras cuando aún no hay agregados).
- `top_apps.csv`: aplicaciones principales del informe.
- `report.json`: resumen íntegro.

UTF-8 con BOM para los CSV, nombres de proceso protegidos frente a interpretación
como fórmula. Son archivos locales del computador; la app muestra su ruta.
Los CSV se han verificado contra una sesión corta real. Importación en Power BI
Windows y prueba de 1–2 horas siguen pendientes.

## Privacidad

No se envían métricas a servidores externos. La app conserva datos y token solo
en memoria; SQLite queda en el equipo y los exports se generan al solicitarlos.
Nombres de aplicaciones pueden revelar hábitos: tratar el historial como datos del usuario.
