# Decisiones tecnicas

## D-001 — Arquitectura multiplataforma desde el primer incremento

- **Fecha:** 2026-10-08
- **Estado:** aceptada
- **Decision:** el agente compartira un modelo de metricas y una interfaz comun;
  las diferencias de macOS y Windows quedaran aisladas en colectores/adaptadores.
- **Motivo:** permite validar ambos equipos con el mismo protocolo y evita que
  la app Android conozca el sistema operativo del PC.
- **Consecuencia:** los sensores no disponibles deben expresarse como `null`
  con un motivo, nunca como un valor inventado.

## D-002 — Transporte inicial por USB

- **Fecha:** 2026-10-08
- **Estado:** aceptada
- **Decision:** la primera conexion Android-PC sera por WebSocket local usando
  `adb reverse`; Wi-Fi, QR y TLS quedan para una fase posterior.
- **Motivo:** reduce superficie de seguridad y variables de depuracion durante
  el MVP.

## D-003 — Estado del agente en Python con psutil

- **Fecha:** 2026-10-08
- **Estado:** aceptada
- **Decision:** CPU, memoria, disco, red, bateria y procesos parten de `psutil`.
  Temperaturas y permisos avanzados tendran adaptadores especificos.
- **Motivo:** cubre datos comunes en macOS y Windows con una dependencia ligera.

## D-004 — Gestor de memoria del proyecto

- **Fecha:** 2026-10-08
- **Estado:** aceptada
- **Decision:** mantener el contexto en Markdown mediante `project-memory.md`,
  `decisions.md`, `PROGRESS.md` y `README.md`.
- **Motivo:** es legible, versionable y suficiente para recuperar el proyecto
  sin introducir una base de datos solo para memoria de desarrollo.

## D-005 — Cliente Flutter sin dependencia WebSocket externa en el MVP

- **Fecha:** 2026-10-08
- **Estado:** aceptada
- **Decision:** el primer cliente usa `dart:io` para WebSocket y estado local
  de Flutter; no incorpora Riverpod/Bloc hasta que existan varias pantallas y
  un modelo de sesion que justifique esa capa.
- **Motivo:** reduce dependencias y permite validar rapidamente el flujo Mac,
  Windows, agente y Android.
- **Consecuencia:** antes de implementar sesiones y acciones se debe revisar la
  estrategia de estado y evitar que la pantalla principal concentre demasiada logica.

## D-006 — Windows y facilidad de arranque se validan desde el núcleo

- **Fecha:** 2026-10-18
- **Estado:** aceptada; sustituye el orden del roadmap que dejaba Windows para fase 4.
- **Decisión:** mantener un lanzador Python común y envoltorios Windows/macOS;
  preparar un entorno aislado por equipo, detectar ADB y automatizar el reenvío USB.
  Windows debe participar en la aceptación de cada incremento del agente.
- **Motivo:** el objetivo central es el mismo Android con cualquiera de los dos
  computadores. La configuración manual ya bloqueó la validación Windows.
- **Tradeoff:** este arranque todavía requiere Python y Platform-Tools externos;
  no equivale al instalador final. No se descarga ADB automáticamente.
- **Consecuencia:** sesiones e informes preceden a acciones/sugerencias; empaquetado
  sin Python externo conserva un hito propio. USB sigue vigente según D-002.

## D-007 — Entorno reproducible y token temporal para el arranque USB

- **Fecha:** 2026-10-18
- **Estado:** aceptada.
- **Decisión:** Python 3.11+, dependencias directas fijadas a las versiones probadas,
  instalación en `agent/.venv` y token aleatorio por ejecución por defecto.
- **Motivo:** evitar diferencias imprevistas al preparar otro equipo y dejar de
  usar una credencial de ejemplo como receta habitual.
- **Tradeoff:** hay que copiar el token al teléfono al reiniciar. El emparejamiento
  persistente/QR vendrá después; `--token` sigue disponible para desarrollo.
- **Consecuencia:** token no persistido por el lanzador y transmitido al proceso
  hijo por entorno; servidor CLI limitado a loopback hasta implementar TLS.
  Actualizar dependencias requiere repetir pruebas en ambos sistemas.

## D-008 — Sesiones persistentes y muestreo compartido para el panel móvil

- **Fecha:** 2026-10-18
- **Estado:** aceptada.
- **Decisión:** un muestreador por agente alimenta clientes e historial; métricas
  cada 1 s y procesos cada 3 s. Una sesión sigue activa aunque no haya teléfono.
  SQLite vive en datos del usuario y el agente bloquea esa carpeta entre procesos.
- **Motivo:** usar el teléfono durante horas exige reconexión sin perder datos;
  varios clientes no deben multiplicar el costo de captura.
- **Tradeoff:** si el agente se cierra, la sesión se recupera como interrumpida
  hasta la última muestra confirmada. No se inventa el período sin captura.
- **Consecuencia:** informes permanentes, detalle por 7 días y agregación a minutos
  de sesiones finalizadas. CSV se exporta en el computador, no en el teléfono.
  Top apps describe los 20 grupos muestreados por memoria, no todos los procesos.

## D-009 — Controlador móvil separado y pantalla activa sin dependencias nuevas

- **Fecha:** 2026-10-18
- **Estado:** aceptada; desarrolla D-005.
- **Decisión:** transporte/estado en `MonitorController` (`ChangeNotifier`), UI
  separada en pantalla con tres destinos; reintentos acotados, cancelación por
  generación y timeout de handshake/datos. Tokens solo en memoria.
- **Motivo:** simplificar pruebas y evitar conexiones tardías, datos congelados
  o reintentos permanentes de tokens rechazados, manteniendo Flutter estándar.
- **Tradeoff:** pantalla activa se integra por un canal Android pequeño; iOS sigue
  pendiente. La bandera afecta solo la ventana visible y se libera al desconectar.

## D-010 — Gráficas temporales locales con escalas explícitas

- **Fecha:** 2026-10-18
- **Estado:** aceptada.
- **Decisión:** vista Gráficas con ventanas de 1/5 minutos y consulta táctil;
  CPU/RAM con escala fija 0–100 %, disco/red con escala común automática por
  pareja. Media/pico se calculan sobre muestras válidas de la ventana visible.
- **Motivo:** comparar tendencias y picos con contexto, evitando minicurvas
  sin ejes o escalas independientes que exageren diferencias.
- **Tradeoff:** el teléfono conserva hasta 5 minutos y 650 puntos en memoria;
  abrir la app no descarga automáticamente toda la sesión SQLite. El historial
  permanente y CSV siguen perteneciendo al computador.
- **Consecuencia:** cortes de conexión/suspensión no se interpolan como valores
  medidos. Sin datos, mostrar espera; barras de procesos comparan RAM relativa
  entre grupos visibles, sin confundirla con porcentaje de RAM del equipo.
- **Implementación:** Flutter CustomPainter y modelo temporal pequeño, sin
  dependencias externas ni cambios al protocolo/agente Windows 0.2.0.

## D-011 — Panel Android en horizontal con distribución según espacio real

- **Fecha:** 2026-10-18
- **Estado:** aceptada; sustituye el comportamiento de orientación libre de 0.3.0.
- **Decisión:** Android usa `sensorLandscape` en la actividad, permitiendo ambos
  sentidos horizontales sin modificar la rotación global del teléfono. Navegación
  lateral, cabecera de 44 dp y contenido dentro de SafeArea.
- **Motivo:** el teléfono funciona como segunda pantalla; la altura debe reservarse
  para datos y curvas, no para controles y tarjetas de configuración grandes.
- **Consecuencia:** panel con seis métricas y curva CPU/RAM; vista Gráficas con
  tres curvas simultáneas; procesos e historial distribuidos en columnas.
- **Tradeoff:** texto ampliado o teclado reducen el espacio; en esas condiciones
  se permite desplazamiento para conservar lectura y acceso a controles. Informes
  extensos y listas de procesos/historial siguen siendo desplazables.
- **Implementación:** shell lateral y variante compacta de la gráfica, reutilizando
  estado, escalas y acciones existentes. No altera agente, protocolo ni pasos Windows.

## D-012 — Grabación opcional, navegación explícita y tema persistente

- **Fecha:** 2026-10-18
- **Estado:** aceptada.
- **Decisión:** denominar Grabar sesión al registro histórico opcional. Informes
  con cabecera fija/X; Atrás cierra modales, vuelve al Panel o solicita salida.
  Menú común para tema Sistema/Claro/Oscuro y salida explícita.
- **Motivo:** el informe ocultaba su cierre al final de la lista; el control
  pantalla activa se confundía con un selector de tema, que no existía.
- **Tradeoff:** salir desconecta solo Android; no termina la sesión ni detiene
  remotamente el agente. El diálogo lo explica, conservando D-008.
- **Implementación:** tema en la raíz Flutter para no recrear el controlador;
  preferencia Android mediante SharedPreferences/canal existente, sin paquetes
  nuevos. Se guarda solo apariencia, nunca token. Otras plataformas usan sistema
  y selección en memoria hasta incorporar persistencia nativa.

## D-013 — Acceso directo al tema mediante iconos

- **Fecha:** 2026-10-18
- **Estado:** aceptada; ajusta el acceso a apariencia de D-012 a petición del usuario.
- **Decisión:** sol/luna/A en cabecera, con selección resaltada y tooltips; retirar
  las entradas de tema del menú ⋮. Preferencia persistente y salida sin cambios.
- **Tradeoff:** ocupa 108 dp adicionales; el nombre del equipo se abrevia según
  espacio, conservando los controles del panel horizontal.

## D-014 — Cierre explícito por PID desde Procesos

- **Fecha:** 2026-10-18
- **Estado:** aceptada a petición del usuario; adelanta implementación de acciones
  mientras la aceptación Windows/prolongada del núcleo permanece pendiente.
- **Decisión:** tarjeta de grupo abre miembros individuales. No ejecutar cierres
  por nombre ni por listas paralelas pids/paths. Members conserva PID+exe+creación.
- **Seguridad:** actions/ central valida token/confirmación, propietario y política
  de protegidos, ticket de un uso por conexión/30 s y revalidación al confirmar.
  Sin elevación. Señales terminate/kill explícitas; no escalado automático.
- **Tradeoff:** usuario elige un PID; no hay cierre atómico de grupo/árbol, ni modo
  foco/restauración. En Windows terminate es forzado. Ausencia de ruta/creación o
  protección verificable bloquea acciones, nunca el monitoreo.
- **Auditoría:** SQLite process_actions, sesión opcional; registrar requested antes
  de actuar y signal_sent/resultado. Si falla registro inicial, no enviar señal.
- **Compatibilidad:** protocolo v1 ampliado con capacidad process_actions, prepare
  y terminate; agentes viejos muestran aviso de actualización. Nuevo ZIP 0.3.0.

## D-015 — Entrega y documentación de instalación común

- **Fecha:** 2026-10-18
- **Estado:** aceptada.
- **Decisión:** README orientado a instalación/uso; explicar acceso por token
  temporal al principio. Mantener D-007: no introducir cuenta/contraseña ni
  publicar credenciales reales por una confusión con Grabar sesión.
- **Entrega:** APK con nombre versionado en dist; ZIP común 0.3.0 con los mismos
  fuentes del agente, ambos lanzadores, LEEME general y guías Windows/Mac.
  ZIP Windows conserva compatibilidad. SHA-256 de los tres entregables.
- **Tradeoff:** Python y Platform-Tools se preparan en cada computador; APK por
  separado. No incluir venv de Mac, credenciales ni SQLite. No equivale a
  instaladores autónomos ni a validación física Windows.

## D-016 — Gráfica ampliada mediante toque y ruta propia

- **Fecha:** 2026-10-18
- **Estado:** aceptada a petición del usuario.
- **Decisión:** tocar una gráfica en Panel/Gráficas abre una ruta sin navegación
  lateral, con X fija/Atrás y selector 1/5 min conservado al volver. Misma
  conexión/historial/pintor; selección táctil de valores en la vista ampliada.
- **Tradeoff:** área disponible respetando cámara/barras, sin cambiar modo
  inmersivo global. Texto grande conserva desplazamiento. Agente sin cambios.

## D-017 — PC Monitor independiente dentro del repositorio Fitflow existente

- **Fecha:** 2026-10-18
- **Estado:** aceptada por la solicitud de publicar en morpheomax/monitoreo_Fitflow.
- **Decisión:** integrar PC Monitor bajo pc-monitor/, conservando fuentes e
  historial de Fitflow de escritorio en la raíz. README principal enlaza las
  dos aplicaciones con instrucciones independientes. Sin force push.
- **Entrega:** versionar solo APK vigente y paquetes/manifest seleccionados,
  excluyendo builds, SDK, venv, claves y datos. Esto permite Download ZIP con APK
  sin necesitar Flutter en Windows. Tradeoff: el APK aumenta el historial Git;
  Releases puede sustituirlo al incorporar firma y distribución públicas.

## D-018 — Transferencia USB temporal y confirmación del equipo

- **Fecha:** 2026-10-18. Aceptada a petición del usuario; ajusta D-007/D-015.
- **Decisión:** lanzador 0.4.0 abre explícitamente la actividad Android 0.7.0
  mediante ADB. Un nonce aleatorio de 256 bits permite recoger una sola vez el
  token mediante HTTP en loopback y un reenvío USB temporal, con caducidad de 90 s.
  El Intent no contiene el token. Sin cuentas, credenciales persistentes ni red LAN.
- **Validación:** Android admite únicamente localhost literal/puertos válidos,
  versión v1, nonce/ruta exactos, sin redirecciones; tamaño/tiempo acotados.
  El usuario confirma nombre y SO del equipo antes de conectar. El WebSocket
  conserva la autenticación existente. Cancelar no reemplaza la conexión actual.
- **Tradeoff:** depende de autorización ADB y de actualizar app/lanzador. Nombre
  y SO son datos declarados por el equipo, no una identidad criptográfica. Un
  equipo con depuración autorizada ya tiene acceso ADB al teléfono. No se ofrece
  confianza permanente ni conexión desatendida. Conexión manual como alternativa.
- **Límites:** el listener temporal se cierra al vencer o detener el lanzador;
  se retira su reenvío al detenerlo. Reparar USB conserva el token actual sin
  volver a emitirlo. No cambia la política de cierre de procesos ni sesiones.


## D-019 — Repositorio propio para PC Monitor

- **Fecha:** 2026-10-18. Aceptada por corrección explícita del usuario; sustituye D-017.
- **Decisión:** publicar PC Monitor en morpheomax/monitoreo_pc_movil, con fuentes,
  APK, paquetes, guías y workflow directamente en la raíz. Extraer únicamente
  el historial de pc-monitor/ para no arrastrar fuentes de Fitflow.
- **Limpieza:** tras verificar la nueva entrega, retirar pc-monitor/, su workflow
  y sus referencias actuales de monitoreo_Fitflow, restaurando su árbol anterior
  a la integración móvil. Conservar el historial remoto; sin force push.
- **Consecuencia:** actualizar enlaces, rutas de clonación, ZIP/guías y CI al
  directorio raíz. No cambia el APK instalado ni el funcionamiento USB. Los
  registros históricos inferiores documentan la ubicación antigua, ya reemplazada.
