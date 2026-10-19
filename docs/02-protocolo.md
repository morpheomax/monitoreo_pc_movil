# Protocolo WebSocket v1 — implementado en 0.3.0

Cada mensaje lleva `v: 1` y `type`. JSON en WebSocket local por USB.
Campos nuevos son compatibles; cambios incompatibles requieren otra versión.

## Handshake

App → agente:

```json
{"v":1,"type":"hello","token":"TOKEN_TEMPORAL","client":"android","app_version":"0.2.0"}
```

Agente → app:

```json
{"v":1,"type":"welcome","host":"Equipo","os":"windows","os_version":"...","cpu_model":null,"cores":8,"ram_total":8589934592,"capabilities":["metrics","processes","sessions","history","session_export"]}
```

`os`: `darwin` para macOS o `windows`. El cliente interpreta datos por capacidades,
no por sistema operativo. El agente envía `session_state` tras `welcome`.
Error de autenticación y cierre:

```json
{"v":1,"type":"error","code":"unauthorized","message":"Token inválido. Usa el token de la ventana del computador."}
```

Timeout de handshake del agente: 10 s; tamaño máximo de entrada 64 KiB.

## Métricas compartidas (cada 1 s)

```json
{"v":1,"type":"metrics","ts":1792340000,
 "cpu":{"total":23.5,"per_core":[20,27],"reason":null},
 "mem":{"used":3000000000,"total":8589934592,"swap_used":1000000000,"pressure":null,"pressure_reason":"platform_adapter_pending"},
 "disk":{"read_bps":1200000,"write_bps":300000,"used":200000000000,"total":500000000000},
 "net":{"down_bps":250000,"up_bps":40000},
 "battery":{"percent":82,"charging":false,"reason":null},
 "temps":{"available":false,"data":null,"reason":"platform_adapter_pending"}}
```

Primera muestra: CPU total `null` y motivo `warming_up`; tasas de E/S en `null`
hasta disponer de dos contadores. `temps.data` disponible contiene sensores
con listas de `{label,current,high,critical}`. Batería ausente devuelve valores
`null` con `reason: no_battery_sensor`. Contadores internos no se transmiten.

## Procesos (cada 3 s)

```json
{"v":1,"type":"processes","ts":1792340000,"groups":[
 {"app":"Google Chrome","cpu":18.2,"mem":2100000000,"pids":[101,102],"paths":["/ruta/ejecutable"],"count":2}
]}
```

Máximo 20 grupos por memoria; la app puede reordenarlos por CPU. CPU de procesos
es suma de porcentajes por núcleo y puede superar 100. PID y rutas no implican
autorización para cerrar. Desde 0.3.0, members contiene identidad individual
{pid,name,exe,create_time,can_terminate,blocked_reason}. Solo se actúa por identidad
individual, con capacidad process_actions y confirmación.

## Solicitudes y estado de sesión

Después del handshake cada solicitud lleva `id` de 1 a 80 caracteres. No se
reenvían automáticamente acciones al perder conexión: recuperar primero el estado.
Una sola sesión activa por equipo.

```json
{"v":1,"type":"session_start","id":"req-1"}
{"v":1,"type":"session_stop","id":"req-2"}
{"v":1,"type":"session_history","id":"req-3"}
{"v":1,"type":"session_export","id":"req-4","session_id":"UUID"}
```

Al conectar y al iniciar/terminar se envía estado. Cambios de estado se difunden
a los clientes autenticados; `active: null` significa que no hay sesión.

```json
{"v":1,"type":"session_state","active":{"id":"UUID","started_at":1792340000.5}}
{"v":1,"type":"ack","id":"req-1","ok":true}
{"v":1,"type":"ack","id":"req-4","ok":true,"export_path":"RUTA_EN_EL_COMPUTADOR"}
{"v":1,"type":"ack","id":"req-5","ok":false,"message":"Ya hay una sesión activa en este equipo."}
```

`started_at`, `ended_at` y picos usan segundos Unix, con precisión fraccionaria
en historial. Detener responde `session_report` con el mismo `id` y un `report`:

```json
{"v":1,"type":"session_report","id":"req-2","report":{
 "session_id":"UUID","host":"Equipo","os":"windows",
 "started_at":1792340000,"ended_at":1792340120,"duration_s":120,
 "sample_count":120,"interrupted":false,
 "cpu":{"avg":31.2,"peak":98.0,"peak_ts":1792340050},
 "mem":{"avg_used":3000000000,"peak_used":4000000000,"peak_ts":1792340060},
 "top_apps":[{"app":"Google Chrome","avg_mem":1200000000,"avg_cpu":10}],
 "top_apps_scope":"top_20_sampled_groups",
 "thermal":{"throttled_s":null,"reason":"throttling_sensor_unavailable"},
 "freed":{"mem_bytes":null,"reason":"actions_not_implemented"}}}
```

Historial responde `{"v":1,"type":"session_history","id":"req-3","reports":[...]}`,
con hasta 30 informes completos, más recientes primero. Si el agente se interrumpió,
el informe se recupera en el próximo arranque con `interrupted: true` hasta la
última muestra confirmada. El teléfono puede desconectarse sin detener la sesión.

Exportar crea `samples.csv`, `minutes.csv`, `top_apps.csv` y `report.json` en una
carpeta del equipo. No devuelve contenido de archivos arbitrarios ni transfiere
CSV al teléfono en este incremento.

## Reservado para etapas posteriores

Perfiles, sugerencias, modo foco, QR/TLS y certificados están
pendientes. No se anuncian en capabilities; comandos desconocidos se rechazan.
Ping/pong del transporte WebSocket está habilitado; no hay ping de aplicación.

## Cierre individual (capacidad process_actions)

Todas las solicitudes llevan v:1, type e id. Token temporal solo en memoria.

```json
{"v":1,"type":"process_prepare","id":"p1","token":"TOKEN","process":{"pid":123,"exe":"/ruta/app","create_time":1792340000.5}}
{"v":1,"type":"ack","id":"p1","ok":true,"ticket":"UN_USO","expires_in_s":30,"process":{"pid":123,"name":"App","exe":"/ruta/app","create_time":1792340000.5}}
{"v":1,"type":"process_terminate","id":"p2","token":"TOKEN","ticket":"UN_USO","confirmed":true,"force":false}
{"v":1,"type":"ack","id":"p2","ok":true,"status":"terminated","pid":123,"message":"Proceso finalizado."}
```

force=false envía terminate, true kill. En Windows terminate también es forzado.
Si sigue activo tras 1.5 s responde still_running: no se afirma que terminó.
Los rechazos usan ack ok:false/message. Ticket válido solo en la conexión que lo
preparó; expira a 30 s y se consume una vez al confirmar. No se reenvían acciones
automáticamente tras reconexión. La lista se refresca en la siguiente muestra.
