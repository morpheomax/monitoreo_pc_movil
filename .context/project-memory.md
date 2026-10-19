# Memoria del proyecto

Repositorio vigente: https://github.com/morpheomax/monitoreo_pc_movil (código en raíz).
Actualizado: 2026-10-18, app 0.7.0 / paquete agente 0.4.0. Consultar README, decisiones
y última entrada de PROGRESS. Uso básico Windows confirmado por el usuario.
La cronología inferior es histórica; el incremento 0.7.0 al final es el vigente.

## Grafo operativo

```text
[PC Monitor]
  ├─ objetivo -> [Android como panel de Windows o macOS]
  ├─ agente -> [Python 3.11+ / psutil / WebSocket v1 / SQLite]
  ├─ cliente -> [Flutter estándar / MonitorController / 4 destinos]
  ├─ transporte -> [USB + localhost + adb reverse]
  ├─ inicio -> [start.py + envoltorios Windows/Mac]
  ├─ reparar enlace -> [--repair-usb / Repair USB Windows.cmd]
  ├─ implementado -> [métricas + procesos + sesiones + informe + CSV]
  ├─ gráficas -> [CPU/RAM + disco + red / 1 y 5 minutos / consulta táctil]
  ├─ siguiente -> [Windows físico + prueba prolongada + Power BI]
  └─ después -> [acciones seguras / sugerencias / instaladores / Wi-Fi]
```

## Estado implementado

- `agent/pcmonitor/metrics.py`: modelo común, tasas, CPU/RAM, disco/red, batería y
  sensores disponibles. Mac agrupa helpers por bundle exterior. CPU primera
  muestra `null` por calentamiento; procesos se escanean cada 3 s.
- `agent/server.py`: muestreador compartido para clientes y sesión; captura solo
  con cliente o sesión. WebSocket autenticado, requests correlacionadas, loopback.
- `agent/history/store.py`: una sesión por equipo, SQLite en datos de usuario,
  informes, historial de últimas 30 sesiones, CSV local y retención de detalle
  de sesiones terminadas de 7 días a minutos. Informe permanente.
- Bloqueo del historial entre procesos. Reinicio recupera sesión interrumpida
  hasta última muestra confirmada; desconexión del teléfono no detiene captura.
- `app/lib/connection/monitor_controller.dart`: reconexión 1–15 s, timeout de
  handshake/datos, cancelación de intentos anteriores y retirada de métricas
  obsoletas. Token rechazado detiene reintentos. No se persisten credenciales.
- `app/lib/screens/dashboard_page.dart`: panel con valores y núcleos; Gráficas con curvas amplias, ejes y
  escalas comunes CPU/RAM, disco/red; consulta táctil, media/pico y 1/5 minutos;
  disco/red, batería/temperatura disponibles; procesos con búsqueda/orden y barras relativas de RAM;
  sesiones, historial, informe y exportación al computador.
- Android mantiene pantalla encendida opcionalmente mientras esté conectado y
  visible, mediante un canal nativo sin dependencias externas.
- Lanzador detecta SDK/PATH y `platform-tools` junto a `start.py`; puede restaurar
  USB sin reiniciar el agente ni perder la sesión.

## Evidencia física de esta sesión

- Samsung SM-A156M autorizado por ADB. Instalado APK ARM64 release 0.4.1+5,
  17.9 MB, versionCode instalado 2005 (ABI split), firma de desarrollo; no hay distribución pública aún.
- Validado token incorrecto → rechazo y token válido → Mac con métricas reales.
- Durante sesión real se retiró el reenvío y se desconectó/reintentó desde la app;
  pantalla Reconectando sin valores obsoletos. SQLite siguió guardando y se
  recuperó el mismo UUID al usar `--repair-usb`, sin volver a introducir token.
- Informe real: 2 min 42 s, 162 muestras; CSV exportado desde Android y comprobado
  contra el mismo conteo. Sesión finalizada, informe disponible en Mac.
- Consumo del agente con Android+sesión: 1.0 % CPU, 18.88 MiB RSS en una ventana
  de 20 s. Reposo sin clientes/sesión: 0.0 % CPU / 8.11 MiB RSS en 20 s. Son
  mediciones breves; no cierran aceptación de 10 min o Windows.
- Tests: 13 agente + 5 lanzador; Flutter analyze sin problemas y 20 tests pasan en 0.4.1, incluidos márgenes,
  teclado y texto de sistema ampliado en horizontal.

## Artefactos y uso Windows

- APK: `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Paquete: `dist/pcmonitor-windows-agent-0.2.0.zip` (fuentes mínimas, sin venv,
  historial ni credenciales). El teléfono ya tiene la app; no requiere Flutter.
- Guía ordenada: `docs/10-ejecutar-windows.md`; copiada como LEEME dentro del ZIP.
- Instalar Python 3.11+ y extraer Platform-Tools junto a `start.py`;
  `Start Windows.cmd`, aceptar depuración de ese PC e introducir su token.
- `Repair USB Windows.cmd` restaura reenvío tras volver a conectar el cable sin
  cerrar el agente. Si se reinicia el agente, cambiará el token por defecto.

## Pendiente y límites

El Panel 0.4.0 quedó horizontal y conectado a la Mac, sin sesión activa; demo finalizada conservada.
Verificados en Samsung curvas reales, selector 5 min, consulta táctil y barras de procesos.
Pruebas de retención/escala/selección y UI incluidas en los 20 tests Flutter.
Android usa sensorLandscape en ambos sentidos sin modificar rotación global.
Navegación lateral, cabecera de 44 dp, Panel 3×2 + curva CPU/RAM y tres gráficas
simultáneas. Procesos y sesiones se distribuyen en columnas. SafeArea protege
cámara y barras del sistema. Texto ampliado/teclado conservan desplazamiento.
D-011 reemplaza la orientación libre de 0.3.0.
Binarios de dependencias Windows x64/Python 3.11 comprobados; falta ejecutar allí.

Windows físico, sesión de 1–2 horas, consumo prolongado e importación CSV en
Power BI. No hay acciones, protegidos, reglas/sugerencias, perfil automático,
Wi-Fi/TLS/QR, instaladores sin Python externo ni sensores avanzados.
No inferir throttling a partir de temperatura ni autorizar cierres por agrupación.

Mantener D-001 a D-017. D-010 documenta gráficas con retención móvil acotada. D-008 define persistencia/recuperación/muestreo; D-009
separación de UI/transporte. El checkout sigue sin `.git`: no hay commits creados.
Actualizar este contexto, README y PROGRESS al cerrar cada sesión.

## Incremento 0.4.1

Tema Sistema/Claro/Oscuro persistido por SharedPreferences Android/canal existente.
Raíz Flutter mantiene estado de tema sin recrear controlador. Paleta clara para
métricas y curvas; rejilla/selección usa onSurface. Control pantalla activa separado.
Informe con título/X fija; Atrás cierra modal o vuelve al Panel, luego ofrece salida.
Salir desconecta Android; grabación del agente sigue vigente (aviso explícito).
Grabar sesión sustituye a Iniciar sesión. Lista de propuestas: docs/11-mejoras-priorizadas.md.
20 tests Flutter y analyze aprobados. Probado claro/oscuro, persistencia tras
reabrir, cierre X, Atrás y salida en Samsung. APK 0.4.1+5 ARM64 / versionCode 2005.

Estado final: Samsung en Panel, conectado a la Mac, tema oscuro, pantalla activa habilitada y sin grabación activa.

## Incremento 0.4.2

Tema mediante tres iconos en cabecera (sol/luna/A) con estado seleccionado y
etiquetas accesibles. Menú ⋮ solo salida. Mismos temas y persistencia de D-012;
D-013 registra el cambio visual. APK 0.4.2+6 / versionCode dividido 2006.

Validado 0.4.2: analyze y 20 tests pasan; Samsung cambia claro/oscuro directamente
con iconos. Panel final conectado a Mac, oscuro y sin grabación activa.

## Estado actual 0.5.0 / agente 0.3.0

Cierre individual desde Procesos: X en tarjeta, miembros con PID/ejecutable, X
individual, confirmación Finalizar/Forzar cierre/Cancelar y resultado explícito.
ProcessDetailsSheet separado. Agentes antiguos sin process_actions deshabilitan
cierre y muestran actualización necesaria. Sin cierre de todo el grupo por nombre.

agent/actions/processes.py concentra política (sistema/agente/ancestros/ADB/otro
usuario/ruta ilegible), token, ticket 30 s/un uso/por conexión y revalidación de
PID+exe+creación. Señales vía psutil, límite 1 cierre/s/conexión, sin escalado ni
reintento automático. Historial process_actions registra solicitado/señal/resultado
con sesión opcional. CSV no exporta este registro todavía. Freed RAM no medida.

Pruebas: 24 agente + 5 lanzador + 22 Flutter; analyze sin problemas. Samsung con
0.5.0+7 (versionCode dividido 2007), APK ARM64 release 17.9 MB. Prueba física con
PID desechable: cancelar, SIGTERM ignorado→still_running, confirmación forzada→
terminated; SQLite contiene seis eventos esperados. Agente protegido visible.
Solo proceso de prueba terminado, ninguna aplicación del usuario. Agente actualizado
reiniciado sin sesión activa; PID de desarrollo 90175. No persistir token en docs.

ZIP vigente dist/pcmonitor-windows-agent-0.3.0.zip, no copiar entornos Mac a Windows.
Validación Windows sigue pendiente; D-014 registra adelanto autorizado de acciones.

Estado final 0.5.0: Samsung en Procesos, filtro vacío, oscuro y conectado, sin
grabación activa. ZIP 0.3.0 validado (19 archivos; CRC/compilación extraída).

- Medición breve del agente actualizado con Android conectado y sin grabación,
  ventana de 20 s: 1.3 % CPU / 17.81 MiB RSS. Es consumo transmitiendo, no reposo;
  falta medición de 10 min y validación Windows para cerrar el presupuesto.

## Instalación documentada y entrega común

README explica que PC Monitor no pide usuario/contraseña: Token del computador
se genera/muestra al abrir el lanzador; Grabar sesión es historial opcional.
Guía completa por orden: autorización Android, Windows/Mac, instalación ADB del
APK, conexión diaria, funciones, cierre, actualización y diagnóstico.
Nueva docs/12-ejecutar-macos.md; Windows revisado sin afirmaciones antiguas de
cierres ausentes. Sin cambio a autenticación/código/app instalada.

Entregables actuales: dist/pcmonitor-android-0.5.0-arm64.apk (copia exacta del APK
compilado), dist/pcmonitor-agent-0.3.0.zip (ambos lanzadores, LEEME y guías) y
ZIP Windows actualizado. dist/SHA256SUMS.txt y dist/README.md. D-015 registra
el empaquetado. CRC, fuentes y compilación extraída comprobados; no venv/tokens
ni SQLite. APK verificado com.innextsolutions.pcmonitor 0.5.0/code 2007/API24/ARM64.

## Gráficas ampliadas y publicación GitHub — 0.6.0

Pendiente del turno anterior completado: tarjeta de gráfica abre ExpandedChartPage,
misma conexión/historial en vivo, X fija y Atrás para volver, ventana 1/5 min
conservada. MetricChart comparte pintor/layout expandido; selección táctil dentro
de la vista ampliada. Texto grande conserva desplazamiento con cabecera fija.
25 tests Flutter pasan, analyze sin problemas; 24 agente + 5 lanzador pasan.
APK 0.6.0+8 ARM64 (code2008) compilado e instalado en Samsung. Validación física
CPU/RAM, selector5min, consulta de huecos/valores y cierreX; disco/red y Atrás.

Repositorio indicado por el usuario: https://github.com/morpheomax/monitoreo_Fitflow.git.
Ya contiene Fitflow Monitor de escritorio; integrar PC Monitor en pc-monitor/
sin sustituir sus fuentes ni historial. D-016/D-017. Guía Windows explica paquetes,
Code→Download ZIP o git clone, carpeta correcta, instalaciónAPK, token y actualización.
.gitignore permite solo entregables vigentes, no builds/venv/SDK/claves/datos.
tools/package_release.py regenera/verifica fuentes, guías, CRC y SHA-256 desde
cualquier SO. Flutter de desarrollo validado 3.47.6. Windows físico aún pendiente.

Publicación inicial confirmada: f80f370 y c8dce8a en main. CI Windows del run
39179879743 pasó agente/arranque/verificación de paquetes. CI Mac detectó captura
prematura de identidad al arrancar Python framework en el fixture; corregida con
señal ready común para ambos tests reales. No se debilita ProcessPolicy.
La copia local monitorpc es independiente del Git monorepo: para próximos pushes,
clonar morpheomax/monitoreo_Fitflow e integrar bajo pc-monitor/ conservando raíz.

- Verificación final GitHub: run39180195390 / commitd8780b0 completó con éxito
  windows-latest y macos-latest (24 tests agente, 5 arranque y coherencia de
  entregables en cada SO). Evidencia: https://github.com/morpheomax/monitoreo_Fitflow/actions/runs/39180195390
- Descarga limpia mediante git archive: APK/ZIP/guías correctos, package_release
  --check y start.py --help ejecutados sin app/build ni venv de Mac. APK instalado
  0.6.0+8 en Samsung. Panel final conectado, oscuro y sin grabación activa.


## Conexión rápida USB — 0.7.0 / paquete 0.4.0

El usuario confirmó instalación/uso básico en Windows con el teléfono. No se
extiende esa evidencia a cierres, consumo prolongado ni la nueva conexión rápida.

start.py abre Android con ADB y un enlace nonce de 256 bits, HTTP solo loopback
y reverse temporal, una recogida, 90 s, no-store y sin logs de credenciales.
Intent sin token; el canal nativo consume/elimina el enlace en memoria. App valida
v1/host literal/puerto/ruta, no sigue redirecciones y limita tamaño/tiempo.
Confirma equipo/SO antes de conectar; cancelar conserva la conexión actual.
Sin cuentas, token persistido, elevación ni confianza permanente. Alternativa
manual y --manual-connection. D-018 ajusta D-007/D-015.

Samsung: APK 0.7.0+9 instalado conservando datos; recepción desde lanzador real
y conexión con métricas reales sin escribir token. Segunda solicitud cancelada
conserva el equipo conectado. Pruebas locales: 29 Flutter, analyze limpio, 24
agente. 9 tests del lanzador pasan: un uso/caducidad/nonce y alternativa manual.

Pendiente: validar el incremento en Windows, sesiones prolongadas y cierre por
aplicación completa (solicitado, aún no implementado). Esa acción debe conservar
identidades, protegidos, auditoría y resultado individual; Windows terminate es
forzado y no puede prometer guardar cambios. Nueva entrega APK0.7.0/ZIP0.4.0.

- Publicado 5ed6537 en main. GitHub Actions39186437103 aprobado en Windows y
  macOS: 24 tests agente, 9 arranque y verificación de fuentes/guías/CRC/SHA-256.
  https://github.com/morpheomax/monitoreo_Fitflow/actions/runs/39186437103
  Confirmada app instalada0.7.0/code2009/API24. Conexión rápida física Windows
  y cierre por aplicación completa permanecen pendientes; el teléfono ya está
  actualizado para usar ambos computadores.


## Repositorio definitivo — D-019

Usuario corrigió destino a morpheomax/monitoreo_pc_movil. PC Monitor está en raíz,
con historial extraído solo de pc-monitor/. Workflow y recetas de clonación/ZIP
adaptados. Las referencias anteriores a monitoreo_Fitflow son históricas.
Retirar integración móvil del árbol actual del repositorio anterior solo después
de verificar la nueva entrega; conservar Fitflow, su historial y su pausa.
Sin cambios al APK/funciones. La carpeta local de desarrollo usará el remoto nuevo.
