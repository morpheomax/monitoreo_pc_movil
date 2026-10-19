# Sensores: qué se puede leer y cómo

La parte más difícil del proyecto no es la app, son las temperaturas. Ser honestos con esto desde el día 1.

| Dato | Windows | macOS (Apple Silicon) | Dificultad |
|---|---|---|---|
| CPU % total / por núcleo | psutil | psutil | Fácil |
| RAM, swap | psutil | psutil (+ "memory pressure" vía `vm_stat`/`memory_pressure`) | Fácil |
| Disco uso | psutil | psutil | Fácil |
| Disco E/S (bytes/s) | psutil (diferencias entre muestras) | psutil | Fácil |
| Red | psutil | psutil | Fácil |
| Batería | psutil | psutil | Fácil |
| Procesos | psutil | psutil | Fácil |
| Temperatura CPU | **LibreHardwareMonitor** (librería .NET, requiere admin) | **No la da psutil.** Opciones: `macmon` (sin sudo) o `powermetrics` (requiere sudo) | Media/Alta |
| Temperatura GPU | LibreHardwareMonitor | macmon / powermetrics | Media/Alta |
| Ventiladores | LibreHardwareMonitor | Macs sin ventilador (Air) no tienen | Media |
| Potencia (W) | LibreHardwareMonitor (según CPU) | macmon / powermetrics | Media |
| S.M.A.R.T. disco | smartctl (smartmontools) | smartctl | Media |

## Estrategia
1. **Fase 0:** probar en TU Mac `macmon` y `powermetrics` y ver cuál entrega lo necesario. Verificar la instalación y licencia de la herramienta antes de depender de ella.
2. En Windows, probar LibreHardwareMonitor expuesto por su servidor web/JSON o vía `pythonnet`.
3. Diseñar `collectors/temps.py` con una interfaz única y una implementación por plataforma.
4. Si no hay sensor: `null` + motivo, y la UI muestra "no disponible", no un cero.

## Notas
- Las Mac sin ventilador (MacBook Air) igual reportan temperatura; sirve para ver estrangulamiento térmico.
- En Windows muchos sensores necesitan ejecutar el agente como administrador; documentar y pedirlo solo para ese módulo.
- Cálculo de tasas (bytes/s): guardar la muestra anterior y dividir por el intervalo real, no por "1 s" supuesto.
