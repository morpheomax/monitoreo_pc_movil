# Mejoras priorizadas — 2026-10-18

## Corregido en Android 0.4.1

- Informe con X fija y contenido desplazable; cierre también con Atrás.
- Atrás desde Gráficas/Procesos/Sesiones vuelve al Panel. En Panel ofrece salir.
- Desde 0.4.2: iconos sol/luna/A para tema; menú ⋮ para Salir. Preferencia de tema
  persistida en Android, independiente del control de pantalla encendida.
- Etiqueta Grabar sesión para distinguir registro histórico de conexión.

Grabar una sesión es opcional: el panel en vivo no la requiere. Al grabar, el
agente guarda métricas en SQLite, calcula medias/picos y principales aplicaciones,
y conserva informe/CSV para comparar jornadas. La grabación sigue si se desconecta
el teléfono o se sale de la app; Finalizar genera el informe. Para detener el
agente usar Ctrl+C en su ventana del computador. No se envía un apagado remoto.

## Orden propuesto

El usuario confirmó el uso básico en Windows con teléfono el 2026-10-18.
Nuevo incremento: conexión rápida USB (app 0.7.0/lanzador 0.4.0), con confirmación
de equipo/SO sin escribir token. Próxima mejora: cierre por aplicación completa
desde la tarjeta, manteniendo validación por PID y procesos protegidos.
Siguen pendientes sesión prolongada, consumo y cierres específicos en Windows.

| Prioridad | Mejora pendiente | Beneficio y condición de aceptación |
|---|---|---|
| 1 | Validación Windows y sesión prolongada | Probar el mismo teléfono en Windows, 1–2 h de captura, reconexión y CSV; medir CPU/RAM del agente durante 10 min. Es el siguiente hito del núcleo. |
| 2 | Estado de grabación más evidente | Contador persistente en cabecera y nombre opcional de sesión; distinguir conexión activa de grabación activa. |
| 3 | Informe visual y comparación de sesiones | Curvas históricas, promedios/picos comparables, tiempo sobre umbrales y comparación antes/después de abrir apps. Requiere consulta histórica acotada al agente. |
| 4 | Alertas por carga sostenida | Avisar por CPU/RAM altas durante un intervalo configurable, con espera entre avisos; explicar causa observada sin atribuir diagnósticos no medidos. |
| 5 | Ampliar gestión de aplicaciones | Cierre individual implementado en 0.5.0 con identidad, protegidos y auditoría. Falta validar Windows y diseñar cierre por aplicación/árbol y visualización del registro. |
| 6 | Instalador y control del agente | Ejecutable por sistema sin Python externo, estado en bandeja y opción Detener agente; diagnóstico USB y actualizaciones. Validar en equipos limpios. |
| 7 | Sensores por plataforma | Temperaturas y presión de memoria cuando la plataforma lo permita; mostrar motivo cuando no estén disponibles. Medir coste y permisos. |
| 8 | Sugerencias y modo foco | Reglas explicables, perfiles y restauración de apps guardando su identidad y argumentos; depende del cierre seguro. |
| 9 | Panel configurable | Elegir métricas, orden, tamaño de texto y modo inmersivo; conservar controles accesibles y bajo consumo. |
| 10 | Wi-Fi local con QR | Emparejamiento con TLS, huella y revocación por dispositivo; conservar USB. Sin exposición a internet. |

El roadmap de docs/06 sigue siendo la referencia para dependencias y cierre de
fases. No se implementan todas estas propuestas en este incremento.
