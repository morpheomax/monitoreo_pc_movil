# Revisión técnica — 2026-10-18

## Conclusión

Hay un prototipo vertical útil: agente Python y app Android. La bitácora registra
el flujo físico Mac → USB → Android. Windows está diseñado en el núcleo común,
pero no hay evidencia de una prueba física terminada. El próximo hito es cerrar
esa validación y la facilidad de arranque; no agregar inteligencia todavía.

## Hallazgos y tratamiento

| Hallazgo | Tratamiento |
|---|---|
| README decía que no existía Flutter; contexto indicaba fases ya implementadas | Actualizados según código y bitácora. |
| Arranque requería activar entornos y configurar ADB a mano | `start.py`, `Start Windows.cmd` y `Start Mac.command`: entorno aislado, detección ADB, selección del teléfono y reenvío automático. |
| Dependencias sin límite superior | Versiones directas fijadas y comprobadas en un entorno limpio; Python mínimo 3.11. |
| Token `desarrollo` utilizado como receta general | Token aleatorio por ejecución en el lanzador, sin archivo y por entorno al proceso hijo. La app todavía requiere introducirlo manualmente. |
| Un JSON válido que no fuera objeto podía romper el handshake | Rechazo seguro y tests para tipos inesperados, versión y credenciales incorrectas. |
| La app mostraba conectado antes de autenticar | Espera `welcome` v1; conexión de socket limitada a 10 s. |
| Tasas de disco/red compartían la muestra anterior entre clientes | Referencia anterior independiente por conexión. |
| El volumen de disco dependía de la unidad actual en Windows y se consultaba dos veces | Selección explícita de la unidad del sistema y una consulta. Validación física pendiente. |
| Windows se había postergado hasta fase 4 | Matriz Windows/macOS en cada incremento y validación inmediata. |
| Acciones antes que historial pese a prioridad de núcleo/sesión | Sesiones e informes pasan antes de acciones y sugerencias. |

## Riesgos técnicos pendientes

- El servidor recolecta síncronamente por cliente, incluyendo procesos cada 1 s.
  Antes de sesiones, usar un único muestreador compartido y reducir frecuencia de
  procesos. Varias conexiones hoy repiten trabajo.
- El cliente concentra transporte/estado/UI en `main.dart`; no hay reconexión
  automática ni cancelación robusta de conexiones simultáneas ni timeout del
  handshake tras abrir el socket. Los datos anteriores pueden quedar visibles
  tras desconectar. Resolver antes de sesiones de varias horas.
- La agrupación por nombre no sirve como autorización para cerrar procesos:
  falta identidad por PID, ruta y creación, lista de protegidos y pruebas de seguridad.
- `docs/02-protocolo.md` mezclaba ejemplos futuros con contrato actual. Se añade
  una sección explícita del contrato implementado; los ejemplos de producto
  no se deben usar como prueba de funcionalidades existentes.
- No hay adaptadores avanzados de sensores, SQLite, retención ni informes.
  Temperatura elevada por sí sola no demuestra estrangulamiento térmico.
- El spike conserva lógica anterior duplicada: para nuevas mediciones usar el
  agente real; unificar o retirar el spike al consolidar los colectores.
- No hay `.git` en esta carpeta. La exclusión de entornos/datos está preparada,
  pero falta inicializar el versionado o recuperar el repositorio original.

## Verificación de esta revisión

Se registra el resultado concreto en la nueva entrada de PROGRESS.md. Las pruebas
unitarias y el WebSocket local no reemplazan la prueba física Windows/Android.
El diagnóstico actual encuentra ADB en el SDK de Mac, sin Android autorizado conectado.

## Prueba pendiente en cada computador

1. Instalar requisitos de README; copiar fuentes sin `.venv` ni carpetas de build.
2. Conectar el mismo Android, abrir el lanzador y usar el token mostrado.
3. Verificar nombre/OS, CPU bajo carga, RAM, disco y procesos contra herramientas del equipo.
4. Desconectar/reconectar el cable y comprobar el procedimiento de recuperación.
5. Medir reposo y transmisión durante 10 minutos; después realizar una sesión de
   1–2 horas cuando exista historial. Registrar versiones y resultados, sin tokens.

## Actualización tras implementación móvil 0.2.0

Resueltos los puntos principales de esta revisión: controlador de conexión
separado, reintentos/cancelación/timeouts, muestreador compartido, cadencia de
procesos, sesiones SQLite, informe, CSV y retención. `docs/02-protocolo.md` ahora
describe íntegramente el contrato implementado. Se probaron en el Samsung físico.

Quedan los elementos explícitos del roadmap: Windows real, prueba prolongada,
Power BI, acciones/protegidos, reglas, sensores avanzados y distribución final.
La evidencia y límites concretos se registran en la última entrada de PROGRESS.
