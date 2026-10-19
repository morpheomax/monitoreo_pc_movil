# PROGRESS.md (bitácora, solo agregar al final)

## Sesión 0 — Planificación
- Definidos alcance, arquitectura, protocolo, sensores, sugerencias, seguridad y roadmap.
- Pendiente: ejecutar Fase 0 (spike de métricas en Mac y Windows).

## Sesión 0b — Ajustes de planificación
- Uso real: sesiones de varias horas en trabajo intenso (no panel 24/7).
- Se agrega modo sesión + informe + historial SQLite (Fase 2.5), perfil automático y modo foco con deshacer (Fase 3).
- Resto de mejoras al backlog.
- Equipo Windows disponible para la Fase 4.
- Siguiente paso: ejecutar `agent/spike_metrics.py` en la Mac y decidir fuente de temperaturas.

## Sesión 1 — Memoria y núcleo multiplataforma
- Se creó el grafo operativo en `.context/project-memory.md`.
- Se creó `.context/decisions.md` con las decisiones de arquitectura multiplataforma,
  transporte inicial USB, `psutil` y mantenimiento de memoria.
- Se amplió `README.md` con el estado real, desarrollo en Mac/Windows y reglas de continuidad.
- Se implementó `agent/pcmonitor/metrics.py` con snapshots normalizados para macOS y Windows:
  CPU, RAM, disco, red, batería, temperaturas disponibles y procesos agrupados.
- Los grupos de procesos conservan PID y ruta para futuras acciones seguras.
- Se añadieron tres tests unitarios para tasas, nombres y agrupación de procesos.
- Se implementó `agent/server.py` con autenticación por token y mensajes WebSocket
  `hello`, `welcome`, `metrics` y `processes`, escuchando por defecto solo en localhost.
- Se creó el cliente Flutter inicial en `app/`: configuración, dashboard Android,
  conexión WebSocket, tarjetas de métricas y lista de procesos.
- Verificado en esta Mac: 3 tests pasan, los módulos compilan, snapshots y welcome
  se serializan a JSON y una conexión WebSocket de integración fue exitosa.
- Flutter, Dart y `adb` no están disponibles en el entorno actual; por eso no se
  pudo ejecutar `flutter analyze`, `flutter test` ni instalar en un teléfono.
- Pendiente inmediato: instalar/verificar Flutter y Android SDK, generar la plataforma
  Android, probar por `adb reverse` y validar el spike y las temperaturas en Windows.

## Sesión 2 — Primer cliente Flutter Android
- Se instaló Flutter 3.47.6 mediante Homebrew y se generó la plataforma Android con
  `flutter create .` dentro de `app/`.
- Se agregó el dashboard funcional con conexión WebSocket, token, métricas y procesos.
- Se agregó el permiso Android de Internet y se cambió el identificador a
  `com.innextsolutions.pcmonitor`.
- `flutter analyze`: sin problemas.
- `flutter test`: todos los tests pasan.
- `flutter build apk --debug`: APK generado en
  `app/build/app/outputs/flutter-apk/app-debug.apk`.
- No se detectó ningún dispositivo Android conectado por ADB.
- Siguiente paso: conectar el teléfono, ejecutar `adb reverse`, levantar el agente
  y validar el flujo completo en el dispositivo.

## Sesión 4 — APK instalado para prueba en Windows
- Se confirmó el teléfono Samsung SM-A156M conectado y autorizado por ADB.
- Se instaló correctamente `app/build/app/outputs/apk/debug/app-debug.apk` con
  el identificador `com.innextsolutions.pcmonitor`.
- La aplicación quedó lista para abrirse y conectarse al agente Windows mediante
  `adb reverse`; no requiere Flutter instalado en Windows.
- Pendiente: ejecutar el agente en Windows y validar métricas reales de ese equipo.

## Cierre de sesión — Continuar mañana
- Se confirma que el APK queda instalado en el teléfono y no requiere reinstalación
  para la prueba en Windows.
- La validación Mac -> Android está completada.
- La prueba Windows queda pendiente porque `adb` no está disponible todavía en ese
  equipo y debe localizarse la carpeta real del proyecto/agente.
- Próximo paso registrado: preparar `adb`, ejecutar el agente Windows y repetir
  `adb reverse tcp:8765 tcp:8765` antes de pulsar Conectar en la app.

## Sesión 3 — Validación física Android por USB
- Se detectó el teléfono Samsung SM-A156M con ADB (`R5CX50C2HQB`).
- Se configuró `adb reverse tcp:8765 tcp:8765` correctamente.
- Se levantó el agente en la Mac con `python server.py --token desarrollo`.
- Se instaló y ejecutó el APK debug en el teléfono.
- El handshake WebSocket fue exitoso; la app mostró estado `Conectado` y el host
  `MacBook-Air-de-Maximiliano.local (darwin)`.
- Se visualizaron datos reales: CPU 21.1 %, RAM 3.3/8.0 GB, disco 5.2 MB/s y
  20 grupos de procesos.
- Flujo Mac -> USB -> Android validado de extremo a extremo.
- Pendiente: repetir exactamente la prueba usando el equipo Windows.

## Sesión 5 — Revisión y arranque multiplataforma (2026-10-18)

- Se revisaron código, arquitectura, decisiones y bitácora: el flujo Mac → Android
  estaba validado anteriormente; Windows continúa sin prueba física terminada.
- Se corrigieron README y grafo de contexto que aún indicaban fases ya implementadas.
- Nuevo `start.py` común y entradas `Start Windows.cmd` / `Start Mac.command`:
  entorno Python aislado, dependencias fijadas, búsqueda de ADB fuera de PATH,
  diagnóstico `--check`, selección `--serial` y `adb reverse` automático.
- Requiere Python 3.11+ y Platform-Tools. No descarga ADB ni es aún un instalador
  sin herramientas externas. No requiere Flutter en Windows para usar el APK.
- Token temporal aleatorio por defecto, sin persistencia ni argumento al proceso
  hijo; CLI del servidor limitado a loopback. `--token` conserva pruebas manuales.
- Handshake robusto ante JSON de tipo inesperado, versión o token incorrectos;
  Android marca Conectado tras `welcome` v1 y limita la apertura del socket a 10 s.
- Referencia de tasas separada por conexión; disco en unidad del sistema Windows
  con una sola consulta. La prueba simulada de unidad no reemplaza Windows real.
- Documentados hallazgos en `docs/09-revision-tecnica.md` y contrato implementado
  en docs/02; diferenciados los mensajes futuros de las capacidades actuales.
- Roadmap revisado: validar Windows y facilidad de arranque desde el núcleo,
  luego sesiones/informes, acciones seguras e inteligencia. Decisiones D-006/D-007.
- Verificaciones: 6 tests del agente y 4 del lanzador pasan; `flutter analyze`
  sin problemas, `flutter test` pasa (1 test) y `flutter build apk --debug` exitoso.
  APK actualizado: `app/build/app/outputs/flutter-apk/app-debug.apk`.
- Entorno limpio preparado correctamente con psutil 7.2.2 y websockets 17.2;
  segunda preparación reutiliza dependencias sin reinstalar.
- Integración WebSocket real en localhost: rechazo de JSON no objeto, handshake
  válido y mensajes `metrics`/`processes` v1 con memoria/disco reales.
- Medición breve del proceso agente en Mac, ventanas de 5 s: reposo 0.0 % CPU /
  33.34 MiB RSS; transmitiendo 2.2 % CPU / 32.45 MiB RSS. Falta validación prolongada
  de 10 minutos y equivalente en Windows; no se considera cerrado el presupuesto.
- ADB localizado en el SDK de Mac. No había Android autorizado conectado: no se
  instaló el nuevo APK ni se repitió la prueba física. El sandbox bloqueó inicialmente
  el servicio ADB; la comprobación autorizada confirmó ausencia de dispositivo.
- No se crearon commits: esta carpeta no contiene repositorio `.git`.
- Próximo paso: conectar Android y probar el lanzador Mac; copiar fuentes sin
  `.venv` a Windows, abrir `Start Windows.cmd`, introducir el token mostrado y
  validar métricas del equipo. Después robustecer conexión/muestreo compartido
  y comenzar SQLite/sesiones antes de acciones destructivas.

## Sesión 6 — App móvil funcional, sesiones y entrega Windows (2026-10-18)

- Samsung SM-A156M conectado/autorizado por ADB; se trabajó con teléfono físico,
  sin emuladores. Instalada app 0.2.0, pubspec +2, versionCode Android 2002 por
  APK ARM64 dividido. Build release de 17.6 MB, todavía firmado para desarrollo.
- Separado transporte/estado en `MonitorController` con ChangeNotifier. Handshake
  y datos con timeout, reintentos 1–15 s, cancelación por generación, sin reintentos
  de tokens rechazados y retirada de métricas obsoletas. Token solo en memoria.
- Tres destinos móviles: Panel con gráficas CPU/RAM y núcleos, disco/red,
  sensores disponibles; Procesos con búsqueda y orden; Sesiones con historial,
  informe y exportación CSV al computador.
- Pantalla activa opcional mediante canal Android, sin paquetes nuevos ni wake
  lock de CPU. Verificado nativamente: FLAG_KEEP_SCREEN_ON se activa conectado
  y se retira al desconectar.
- Agente con un muestreador compartido, métricas cada 1 s y procesos cada 3 s;
  sin clientes ni sesión no captura. En Mac los helpers se reúnen por bundle
  exterior: comprobado en pantalla Chrome (29 procesos) y VS Code (31 procesos).
- Implementado SQLite en datos del usuario, sesión por equipo, registro continuo
  aunque se desconecte Android, recuperación como interrumpida, informe permanente,
  detalle 7 días a minutos y exportación de samples/minutes/top_apps/report.
- Bloqueo del historial entre procesos para impedir que otra instancia recupere
  una sesión que sigue viva. No hay aún acciones de cierre ni sugerencias.
- Prueba física: token incorrecto rechazado; token válido conecta con datos reales.
  Se retiró el reenvío ADB (los sockets existentes siguen funcionando), luego se
  desconectó/reintentó desde la app para probar el enlace no disponible. Mostró
  Reconectando sin valores antiguos; SQLite siguió registrando. `--repair-usb`
  restauró el reenvío, la app reconectó sola y recuperó el mismo UUID de sesión.
- Sesión real terminada desde Android: 2 min 42 s y 162 muestras. Informe visible
  y conservado en historial. CSV exportado desde el teléfono: 162 filas de samples
  coherentes con report.json y top_apps.csv; verificados los archivos reales.
- `--repair-usb` y `Repair USB Windows.cmd` permiten restaurar el enlace sin cerrar
  el agente ni perder la sesión/token. Detección de platform-tools junto al lanzador
  evita configurar PATH. Envoltorios conservan el código de salida del agente.
- Verificaciones: 13 tests agente (informes/retención/recuperación/agrupación,
  bloqueo e integración WebSocket) + 5 del lanzador pasan. Flutter analyze sin
  problemas y 8 tests pasan (conexión, cancelación, rechazo, reconexión y UI).
- Medición breve del proceso real: sesión+Android, 20 s → 1.0 % CPU / 18.88 MiB RSS;
  reposo sin clientes ni sesión, 20 s → 0.0 % CPU / 8.11 MiB RSS. RSS es memoria
  residente de esa ventana; falta medición prolongada y en Windows.
- Paquete entregable: `dist/pcmonitor-windows-agent-0.2.0.zip`, 16 archivos, 21 KB.
  Contiene fuentes del agente/lanzadores/tests y LEEME; no venv, datos, token ni APK.
  ZIP extraído, CRC comprobado y fuentes compiladas correctamente en temporal.
- Verificada disponibilidad de wheels Windows x64 / Python 3.11 para psutil 7.2.2
  y websockets 17.2. No equivale a ejecutar Windows; su prueba física sigue pendiente.
- Guía Windows ordenada en `docs/10-ejecutar-windows.md` y dentro del ZIP.
  Actualizados README, app/README, arquitectura, protocolo, sesiones, roadmap,
  contexto y decisiones D-008/D-009.
- Teléfono queda con app instalada, panel conectado a la Mac y sin sesión activa.
  Se conserva la sesión de demostración finalizada. No se crearon commits (.git ausente).
- Próximo paso: llevar el ZIP a Windows, instalar Python/Platform-Tools, autorizar
  ese computador e iniciar con su token; validar sesión de 1–2 horas, consumo
  durante 10 minutos e importación en Power BI. Después, módulo de acciones seguro
  con identidad de proceso/protegidos y tests antes de habilitar cierres móviles.

## Sesión 7 — Gráficas para comparar consumo (2026-10-18)

- Nueva app 0.3.0+3 (ARM64 dividido, versionCode 2003, release de 17.7 MB).
- Vista Gráficas en navegación de cuatro destinos: Panel, Gráficas, Procesos y
  Sesiones. Sustituye las minicurvas sin ejes del panel por curvas detalladas.
- CPU/RAM comparten escala fija 0–100 %. Disco: lectura/escritura; red:
  bajada/subida. Cada pareja comparte autoescala en bytes/s visible en el eje.
- Ventanas 1/5 minutos, valor actual, media/pico de muestras válidas y selección
  por toque o arrastre con hora y valores. Retención móvil de 5 min y máximo 650
  puntos; timestamps de recepción. Sin datos no se muestra cero ficticio.
- Cortes de conexión y tramos separados más de 3 s no se unen visualmente.
  El almacenamiento SQLite del agente no cambia ni se descarga entero a la app.
- Procesos incorpora barras de RAM relativas al mayor grupo visible, con
  explicación para no confundirlas con porcentaje de memoria total del equipo.
- Modelo temporal y widget de gráfica separados; Flutter CustomPainter sin
  dependencias nuevas. Decisión D-010. Agente/protocolo compatibles con 0.2.0.
- Verificado: Flutter analyze sin problemas, 13 tests pasan; pruebas de retención,
  escala común, ausencia de datos, selección táctil, navegación y reconexión.
- Prueba física Samsung: instalación, conexión con datos reales, selector 5 min,
  consulta táctil (hora y CPU/RAM), curvas de disco/red e inspección visual.
  Detectada etiqueta de velocidad partida; corregida con ajuste a una línea,
  repetidos análisis/tests/build e instalación de la compilación final.
- README, app/README, arquitectura, UI, contexto y guía Windows actualizados.
  LEEME del ZIP Windows actualizado y CRC verificado; fuentes del agente sin cambios.
- APK: `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
  Teléfono queda con la vista Gráficas conectada; las muestras se acumulan en vivo.
- Pendiente: Windows físico y prueba prolongada de sesión; siguientes bloques del
  producto siguen siendo acciones seguras, sugerencias y distribución final.

## Sesión 8 — Interfaz horizontal para el Samsung (2026-10-18)

- App 0.4.0+4, APK ARM64 release de 17.8 MB, versionCode dividido 2004.
- Actividad Android configurada sensorLandscape: permite ambos sentidos
  horizontales sin modificar ajustes globales de rotación. Decisión D-011.
- Nuevo shell lateral con NavigationRail, cabecera de 44 dp y SafeArea para
  cámara/barras. Conexión, sesión, pantalla activa y desconexión en cabecera.
- Panel: cuadrícula 3×2 con CPU/RAM, disco/red, batería del PC y temperatura;
  barras por núcleo y gráfica CPU/RAM simultánea. No requiere desplazamiento
  vertical a tamaño de texto normal en el Samsung.
- Gráficas: tres tarjetas simultáneas (CPU/RAM, disco, red), selector 1/5 min,
  leyendas/media/picos compactos y consulta táctil. Ayuda en botón de información.
  Variante compacta reutiliza el mismo modelo y pintor de curvas.
- Procesos: filtro lateral y tarjetas por columnas con desplazamiento propio.
  Sesiones: control a la izquierda e historial a la derecha. Informe extenso
  conserva desplazamiento, revisado físicamente en horizontal.
- Con teclado o texto ampliado se usan áreas desplazables; no se desactiva la
  escala de texto del sistema. Corregidas etiquetas del eje temporal y cabecera/
  navegación para evitar desbordamientos con texto a 1.5×.
- Ajustadas etiquetas compactas (BATERÍA PC, escritura/subida) y sensor ausente
  en gris, evitando títulos cortados o flechas aisladas en el panel.
- Verificado: Flutter analyze sin problemas, 17 tests pasan, incluida geometría
  832×384 con márgenes 24/48/24, seis métricas y curva visibles, tres gráficas
  lado a lado, teclado y texto del sistema ampliado. Build release exitoso.
- Pruebas físicas en Samsung: captura real 2340×1080, giro automático al abrir,
  formulario/token con teclado, conexión y métricas reales; inspección visual de
  Panel, Gráficas, Procesos, Sesiones e informe existente. Panel y tres gráficas
  completos dentro de márgenes del sistema, sin desplazamiento vertical.
- Se instaló la compilación final tras ajustar etiquetas. El teléfono queda
  horizontal, conectado al agente de la Mac, en Panel y sin sesión activa.
- Actualizados README, app/README, arquitectura, UI, contexto y guía Windows.
  LEEME dentro del ZIP Windows actualizado y CRC comprobado. Agente/protocolo
  siguen en 0.2.0; no cambian los pasos de conexión Windows.
- APK: `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
  No se crearon commits: el checkout sigue sin .git.
- Pendiente: validación física Windows y sesiones prolongadas; después acciones
  seguras, sugerencias y distribución final según roadmap.

## Sesión 9 — Cierre, navegación y temas reales (2026-10-18)

- App 0.4.1+5 instalada en Samsung, ARM64 release 17.9 MB, versionCode 2005.
- Detectado tema oscuro fijo: el icono sol/luna controlaba solo pantalla activa.
  Menú ⋮ permite Sistema/Claro/Oscuro; preferencia Android en SharedPreferences,
  sin nuevas dependencias ni credenciales persistidas. Tema raíz conserva conexión.
- Paleta clara para valores/curvas/procesos; rejilla y marcador según onSurface.
  Iconos de pantalla sustituyen sol/luna para evitar confusión.
- Informe con X y título fijos fuera de lista; cierre inferior conservado.
  Atrás cierra modal, vuelve al Panel desde otros destinos y en Panel ofrece salir.
- Salir desconecta cliente y cierra actividad; no finaliza grabación ni agente.
  Diálogo explica grabación activa o Ctrl+C local. Etiqueta Grabar sesión aclara
  el propósito opcional del registro. Decisión D-012.
- Flutter analyze sin problemas; 20 tests pasan: 17 anteriores y 3 pruebas nuevas
  para temas/persistencia, Atrás/salida/cancelación e informe largo/X fija.
- Build release e instalación correctos. Samsung: panel/gráficas en claro con
  datos reales, vuelta al Panel, informe previo/X, diálogo y salida, reinicio con
  claro conservado y token vacío, cambio a oscuro y reconexión final.
- Capturas: dist/previews/graficas-claro.png e informe-cierre.png.
- docs/11-mejoras-priorizadas.md detalla propuestas y criterios: Windows/larga
  duración, grabación visible, informe comparativo, alertas sostenidas, acciones
  seguras, instaladores, sensores, foco, personalización y Wi-Fi seguro.
- README, app/README, arquitectura, UI, guía Windows, contexto y decisiones
  actualizados. Agente/protocolo 0.2.0 sin cambios; Windows físico sigue pendiente.
- No se crean commits: checkout sin .git. Siguiente hito: aceptación Windows y
  sesión de 1–2 h; propuestas no equivalen a funciones implementadas.

Estado final: Samsung en Panel, conectado a la Mac, tema oscuro, pantalla activa habilitada y sin grabación activa.

## Sesión 10 — Tema mediante iconos directos (2026-10-18)

- App 0.4.2+6 instalada en Samsung; APK ARM64 release 17.9 MB / versionCode 2006.
- Sol/luna/A en cabecera para claro/oscuro/sistema, resaltando selección y con
  tooltip/etiqueta accesible. Ya no requiere abrir menú. Persistencia conservada.
- Menú ⋮ conserva Salir. Cabecera adapta equipo/estado al espacio para incorporar
  los tres iconos sin desbordar; teclado y texto ampliado conservan sus ajustes.
- Flutter analyze sin problemas y 20 tests pasan. Pruebas de tema adaptadas al
  acceso directo; regresión de dimensiones Samsung, teclado y texto grande pasan.
- Prueba física: sol activa claro, luna oscuro; panel conectado y controles
  visibles. Captura dist/previews/tema-iconos.png. Sin grabación activa.
- README, app/README, arquitectura, UI, contexto, propuestas, guía Windows y
  LEEME del ZIP actualizados. D-013 registra el acceso visual. Agente sin cambios.
- Pendientes del núcleo: Windows físico y sesión prolongada. Sin commits (.git ausente).

## Sesión 11 — Cierre desde Procesos (2026-10-18)

- App 0.5.0+7 instalada, APK ARM64 release 17.9 MB / versionCode 2007.
- Procesos incorpora X por tarjeta para abrir miembros con PID/ruta y X individual.
  Confirmación Cancelar/Finalizar/Forzar cierre; título/cierre fijos y lista desplazable.
  Protegidos muestran motivo sin botón. Agente antiguo pide actualizar capacidad.
- Nuevo agent/actions/processes.py: política central de protegidos/propietario,
  PID+exe+creación, token y confirmación, tickets 30 s/un uso/por conexión, límite
  1 cierre/s/conexión. Relectura de identidad antes de señal psutil; sin cierre por
  nombre o árbol, elevación, escalado automático ni reintento tras reconexión.
- Protocolo v1 ampliado con process_actions, process_prepare/process_terminate.
  Grupos incluyen members emparejados; listas pids/paths permanecen compatibles.
- SQLite agrega process_actions con sesión opcional, pedido/señal/resultado. Si
  falla registro inicial no se envía señal. Freed RAM queda null/not_measured.
- Agente reiniciado tras verificar ausencia de sesión activa; mismo enlace USB.
- Tests: 24 agente (10 nuevos de acciones + integración WebSocket nueva), 5 lanzador,
  22 Flutter (dos nuevos de cancelar/confirmar/protegidos/forzado/rechazo). Analyze
  sin problemas. Build e instalación correctos, sin emulador.
- Samsung físico: proceso propio desechable PID 91625; visible junto al agente
  protegido 90175. Cancelar no cierra; Finalizar con SIGTERM ignorado devuelve
  still_running; nueva confirmación Forzar cierre devuelve terminated. PID ausente,
  agente vivo y auditoría de seis eventos exactos verificados en SQLite.
- Capturas confirmar-proceso.png y proceso-finalizado.png en dist/previews.
- Documentación/contexto/roadmap actualizados y decisión D-014 registrada a petición
  del usuario. Nuevo paquete Windows 0.3.0; validación física Windows pendiente.
- No se crean commits: checkout sin .git. Pendientes: Windows, sesiones prolongadas,
  cierre por aplicación/árbol y visualización/exportación del registro de acciones.

- Paquete Windows 0.3.0: 19 archivos/27473 bytes; CRC y compilación de fuentes
  extraídas correctos. Teléfono queda en Procesos, filtro limpio, oscuro y conectado
  a la Mac, sin grabación activa. Proceso desechable eliminado.

- Medición breve del agente actualizado con Android conectado y sin grabación,
  ventana de 20 s: 1.3 % CPU / 17.81 MiB RSS. Es consumo transmitiendo, no reposo;
  falta medición de 10 min y validación Windows para cerrar el presupuesto.

## Sesión 12 — Instalación ordenada y credenciales explicadas (2026-10-18)

- Aclarado que no existen cuenta/usuario/contraseña en el flujo actual: el acceso
  usa token temporal generado por start.py y mostrado en el computador. No se
  incluyeron credenciales reales ni se cambió autenticación (D-007 conservada).
- README reordenado para usuario final: archivos, preparar Android, Windows/Mac,
  instalar/actualizar APK con ADB, obtener token/conectar, funciones, grabar sesión,
  cerrar, diagnóstico y actualización. Distingue conexión de registro histórico.
- Nueva guía Mac docs/12-ejecutar-macos.md. Guía Windows reescrita, incluida
  instalación Android y cierre por PID; retirado texto obsoleto de cierres ausentes.
- APK copiado a dist/pcmonitor-android-0.5.0-arm64.apk; idéntico al compilado y
  verificado con AAPT: app 0.5.0/code 2007, API mínima 24, ABI arm64-v8a.
- ZIP común dist/pcmonitor-agent-0.3.0.zip: fuentes mínimos vigentes, ambos
  lanzadores, LEEME general y guías Windows/Mac. ZIP Windows actualizado.
  Fuentes idénticas al checkout, CRC y compilación de Python extraído correctos.
  Excluidos venv, tokens e historial; herramientas de terceros y APK separados.
- Manifiesto SHA256SUMS y dist/README para identificar entregables. Start Mac.command
  conserva bit ejecutable en metadatos del ZIP común. Decisión D-015.
- Referencias de preparación USB/ADB y descargas verificadas en documentación
  oficial de Android, Python y Samsung. No se añadieron dependencias ni cambiaron
  fuentes de la app/agente; no se recompiló ni reinstaló la app por estos cambios.
- Windows físico y pruebas prolongadas permanecen pendientes. No hay commits
  porque el checkout no contiene .git.

## Sesión 13 — Gráficas completas y entrega desde GitHub (2026-10-18)

- Retomado trabajo interrumpido por límite de aprobación de herramientas en el
  turno anterior. Corregida prueba de lista diferida con texto grande; 25 tests
  Flutter pasan, analyze sin problemas, APK release ARM64 0.6.0+8 compilado.
- Toque en tarjeta/curva de Panel o Gráficas abre ruta ampliada, misma conexión/
  historial, X fija/Atrás y selector1/5min persistente al regresar. Consulta por
  toque/arrastre dentro de la ampliada; sin huecos inventados ni otra conexión.
- Texto grande/altura pequeña permiten desplazamiento conservando cabecera.
  Pruebas cubren geometría, actualización en vivo, tres gráficas, cierre/origen,
  ventana, datos ausentes y accesibilidad. D-016.
- Instalado APK en Samsung, probado CPU/RAM ampliado con métricas reales,
  selector5min, consulta y cierreX; disco/red y retornoAtrás. Captura local
  dist/previews/grafica-ampliada.png. Agente compatible0.3.0 sin cambios.
- 24 tests agente y 5 lanzador pasan. Sin cambios a acciones ni historial.
- Usuario indicó morpheomax/monitoreo_Fitflow; remoto ya contiene Fitflow Monitor
  de escritorio. Integración aditiva bajo pc-monitor/, conservando su historial
  y fuentes. README principal y contexto de ambos proyectos actualizados. D-017.
- Guía Windows desde GitHub: paquetes/directorio pc-monitor/, Code→Download ZIP
  o clone, PlatformTools, APK, token, uso y actualización git pull --ff-only.
- .gitignore/.gitattributes excluyen claves/datos/entornos y permiten solo APK y
  paquetes vigentes; finales de línea cmd para Windows. Nuevo empaquetador
  tools/package_release.py con modo --check (fuentes/guías, CRC, SHA-256).
- Próximo hito operativo sigue siendo Windows físico y sesión prolongada. Las
  pruebas automatizadas y Mac no sustituyen esa validación con teléfono.

- Publicados f80f370 (PC Monitor) y c8dce8a (guías/CI) en main del repositorio
  indicado. Verificado remoto. GitHub Actions 39179879743: Windows completó
  agente/arranque/paquetes correctamente; macOS detectó carrera de arranque en
  el fixture del proceso desechable, no en la política de cierre.
- Fixture común process_fixture.start_worker espera señal ready antes de capturar
  PID/ruta/creación, evitando el salto de ejecutable del Python framework de Mac.
  Protecciones intactas. 24 tests agente pasan tras ajuste. Acciones oficiales
  actualizadas a checkout v5/setup-python v6 (revisiones fijadas, Node24).

- Verificación final GitHub: run39180195390 / commitd8780b0 completó con éxito
  windows-latest y macos-latest (24 tests agente, 5 arranque y coherencia de
  entregables en cada SO). Evidencia: https://github.com/morpheomax/monitoreo_Fitflow/actions/runs/39180195390
- Descarga limpia mediante git archive: APK/ZIP/guías correctos, package_release
  --check y start.py --help ejecutados sin app/build ni venv de Mac. APK instalado
  0.6.0+8 en Samsung. Panel final conectado, oscuro y sin grabación activa.


## Sesión 14 — Conexión USB sin escribir token (2026-10-18)

- Usuario confirmó instalación y funcionamiento básico en Windows. Se registra
  como evidencia del usuario; no implica validación de sesiones largas/cierres.
- App0.7.0+9 y paquete0.4.0: el lanzador abre Android por ADB; enlace nonce de
  un uso permite recoger token por loopback/reverse, caduca en90s. Intent sin
  token. Credenciales en memoria, no-store, sin logs ni archivos de credenciales.
- Confirmación con nombre/SO, Conectar/Cancelar. Cancelar conserva la conexión
  actual; cambiarla avisa que grabaciones siguen en el equipo anterior. Conexión
  manual sigue disponible y --manual-connection evita apertura automática.
- Canal nativo consume enlace tanto en apertura fría como onNewIntent. Flutter
  valida versión/ruta/host/puerto/tamaño/timeout; no sigue redirecciones. D-018.
- 29 tests Flutter, analyze limpio, 24 tests agente. Tests de arranque ampliados
  para nonce, un uso, caducidad, token fuera de argumentos, cancelación/aceptación
  en UI y funcionamiento manual ante fallo del emparejamiento.
- Agente de desarrollo previo sin sesión activa, comprobado antes de reiniciar.
  APK actualizado en Samsung mediante install-r; lanzador real envió conexión,
  confirmación equipo/macOS observada y métricas reales recibidas sin escribir.
  Segunda entrega con credencial desechable cancelada: conserva conexión real.
- README, guías Windows/Mac, arquitectura, roadmap y contexto actualizados.
  Próxima mejora solicitada: cerrar aplicación completa desde tarjeta, pendiente
  de diseño/implementación segura; no se cambiaron señales ni protección por PID.

- Validación final: 9 tests del lanzador pasan; ZIP común/Windows 0.4.0
  regenerados con fuentes y guías idénticas, CRC y SHA-256 correctos.
  App0.7.0+9 instalada; Samsung conectado con métricas reales, sin grabación.
- La prueba de cancelación física usó credencial desechable: no envió acciones
  ni reemplazó la conexión real. Agente anterior reiniciado sin perder sesiones.

- Publicado 5ed6537 en main. GitHub Actions39186437103 aprobado en Windows y
  macOS: 24 tests agente, 9 arranque y verificación de fuentes/guías/CRC/SHA-256.
  https://github.com/morpheomax/monitoreo_Fitflow/actions/runs/39186437103
  Confirmada app instalada0.7.0/code2009/API24. Conexión rápida física Windows
  y cierre por aplicación completa permanecen pendientes; el teléfono ya está
  actualizado para usar ambos computadores.


## Sesión 15 — Separación de repositorios (2026-10-18)

- El usuario corrigió el destino: repositorio oficial morpheomax/monitoreo_pc_movil.
  Se extrae exclusivamente el historial de pc-monitor/ y se publica en raíz.
- Enlaces y recetas Windows/Mac ajustados al nuevo repositorio, sin subcarpeta.
  Workflow trasladado a raíz; ZIP regenerados con las guías corregidas.
- APK0.7.0 y agente0.4.0 sin cambios de lógica; no requiere reinstalar Android.
- D-019 sustituye D-017. Tras verificar la entrega nueva, se retiró la integración
  móvil del árbol actual de monitoreo_Fitflow conservando Fitflow y su historial.

- Nuevo repositorio publicado fef5ae6, descargado desde GitHub y comprobado con
  package_release --check y start.py --help, sin SDK ni entorno del Mac. Workflow
 39186773883 aprobado Windows/macOS: 24 tests agente, 9 arranque y paquetes.
  https://github.com/morpheomax/monitoreo_pc_movil/actions/runs/39186773883
- Limpieza anterior publicada b5a1280. Su árbol coincide exactamente con168aec5
  (antes de PC Monitor): Fitflow intacto, sin subcarpeta/workflow/referencias
  móviles actuales. Historial conservado; no se hizo force push.
- Carpeta local monitorpc inicializada con el historial móvil extraído y remoto
  correcto, rama main siguiendo origin/main; entornos/builds/datos conservados.


## Sesión 16 — Cierre y semana de prueba (2026-10-18)

- Usuario pidió cerrar por hoy, guardar contexto completo y retomar tras probar
  la app del19 al25 de octubre. Desarrollo en pausa, sin nuevas funciones ni
  orden de detener agentes/grabaciones existentes. Sin recordatorio programado.
- Registrado resultado posterior a la separación: por nueva instrucción explícita
  se vació TODO main de monitoreo_Fitflow en29a4d50, historial conservado.
  PC Monitor no cambió; sigue en monitoreo_pc_movil. D-020 corrige el estado final.
- Nueva .context/retomar.md resume entrega, repositorios, funcionalidades, pruebas,
  límites y primera acción. README/contexto enlazan retoma y guía de prueba semanal.
- Próximo: feedback del usuario, correcciones reproducibles y después cierre de
  aplicación completa desde tarjeta, aún pendiente de implementación segura.
- Sin cambios de lógica/APK/paquetes. Última evidencia:29 Flutter/analyze limpio,
 24 agente/9 arranque y CI39186773883 aprobada. Esta sesión solo verifica
  coherencia de paquetes y documentación; no repite pruebas ni usa el teléfono.
