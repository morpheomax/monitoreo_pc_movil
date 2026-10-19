# Motor de sugerencias

Principio: **sugerir con explicación, nunca matar sin confirmación, y nunca tocar lo crítico.**

## Pasos del motor
1. **Agrupar** procesos por aplicación (Chrome tiene decenas de procesos; mostrar uno).
2. **Clasificar** cada grupo con la base de conocimiento (`rules/processes.yaml`).
3. **Aplicar perfil activo** (Datos, Desarrollo, Ninguno).
4. **Evaluar** umbrales: consumo sostenido (ej. > 60 s), tiempo sin foco, categoría.
5. **Emitir** sugerencia con motivo, ahorro estimado y riesgo.

## Categorías
- `critical`: nunca sugerir ni permitir matar (kernel, WindowServer, explorer, launchd, csrss, svchost, etc.).
- `work_tool`: herramientas del perfil activo (se protegen mientras el perfil está activo).
- `background_optional`: se pueden cerrar sin pérdida (Teams, Slack, Spotify, updaters, OneDrive sync, Dropbox).
- `browser`: se sugiere cerrar pestañas/ventana, no matar todo.
- `unknown`: solo informar, nunca sugerir cerrar.

## Perfil "Datos" (SQL Server, Power BI, Python)
Proteger: `sqlservr`, `msmdsrv` (motor interno de Power BI Desktop), `PBIDesktop`, `python`, `Code`, `ssms`, `azuredatastudio`.
Sugerir cerrar si consumen y no están en uso: Teams, Slack, Spotify, Chrome con muchas pestañas, Docker Desktop (si no hay contenedores en uso), updaters.

## Perfil "Desarrollo"
Proteger: `Code`, `node`, `docker`, `php`, `mysqld`, `python`.
Sugerir cerrar: apps de comunicación, múltiples ventanas de navegador, servidores `node` huérfanos sin conexiones activas.

## Caso especial: SQL Server
SQL Server **usa toda la RAM que puede por diseño** (hasta `max server memory`). Matarlo no es la solución.
La sugerencia correcta es: "SQL Server usa 6 GB. Puedes limitar su memoria máxima" (con instrucción), no "cerrar".
Misma lógica para otros motores que cachean memoria a propósito.

## Caso especial: procesos huérfanos
Un `node` o `python` sin consola padre, sin conexiones de red y con CPU alta sostenida es candidato a "proceso colgado".
Verificar ruta del ejecutable antes de sugerir.

## Formato de reglas (ejemplo)
```yaml
- match: {name: ["sqlservr.exe"]}
  category: critical_service
  protected: true
  advice: "Limita 'max server memory' en vez de cerrarlo."
- match: {name: ["Teams.exe", "ms-teams.exe"]}
  category: background_optional
  suggest_if: {idle_seconds: 300, mem_mb_over: 500}
  profiles_boost: [data, dev]
- match: {name: ["chrome.exe", "Google Chrome"]}
  category: browser
  group: true
  suggest_if: {mem_mb_over: 2000}
  action_hint: "Cierra pestañas pesadas"
```

## Medición de "no lo estás usando"
- Ventana en primer plano / tiempo desde último foco (requiere APIs por SO; versión 1 puede basarse solo en CPU baja + mucha memoria).
- Marcar como mejora de fase posterior.

## Mejora opcional
Un LLM puede explicar procesos desconocidos ("¿qué es `mdworker_shared`?"). Siempre como apoyo informativo; la decisión de cerrar sigue en reglas y en el usuario.

## Perfil automático (agregado)
Reglas simples, evaluadas cada pocos segundos con histéresis (no cambiar de perfil por un parpadeo):
- Aparece `PBIDesktop`, `sqlservr` con actividad o `ssms` → perfil **Datos**.
- Aparece `Code` + `node`/`php`/`docker` activos → perfil **Desarrollo**.
- Ambos presentes → gana el de mayor consumo sostenido; se muestra el motivo en pantalla.
- El usuario puede forzar un perfil; el forzado manual desactiva el automático hasta fin de sesión.

## Modo foco con deshacer (agregado)
1. El usuario toca "Modo foco".
2. La app muestra las sugerencias de riesgo bajo preseleccionadas; el usuario confirma.
3. El agente guarda en la sesión: nombre, ruta del ejecutable y argumentos de cada app.
4. Cierra de forma suave (`graceful`); si no responde en unos segundos, pregunta antes de forzar.
5. "Deshacer" reabre por ruta lo cerrado. Las apps que no se pueden relanzar se informan, no se ocultan.
- Nunca incluir en el modo foco procesos `critical`, `work_tool` del perfil activo ni `unknown`.

## Backlog de reglas
- Fugas de memoria: crecimiento sostenido (pendiente positiva en una ventana de 10–15 min sin caídas).
- Línea base personal: percentiles por hora del día a partir del historial.
