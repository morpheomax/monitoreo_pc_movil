# UI de la app Android

## Modelo de uso
Se usa en **sesiones de varias horas** durante trabajo intenso, no todo el día.

## Pantallas
1. **Dashboard (principal, apaisado):** CPU, RAM, disco, temperatura, red en tarjetas/gráficos + reloj + clima. Botón grande Iniciar/Detener sesión.
2. **Procesos:** lista agrupada por app, orden por CPU o memoria, botón cerrar.
3. **Sugerencias:** tarjetas con motivo, ahorro estimado y riesgo; botones "Cerrar" / "Ignorar". Botón **Modo foco** con "Deshacer".
4. **Informe de sesión:** resumen al terminar, historial de sesiones anteriores, exportar CSV.
5. **Ajustes:** perfil (auto/manual), umbrales de alertas, emparejamiento, ciudad del clima.

## Modo panel durante la sesión
- Mantener pantalla activa mientras hay sesión (wake lock; paquete `wakelock_plus`); liberarlo al terminar.
- Orientación apaisada, modo inmersivo (ocultar barras).
- Pantalla AMOLED (Galaxy A15): fondo oscuro y brillo bajo; con sesiones de pocas horas el riesgo de quemado es menor, pero mantener un desplazamiento leve de elementos cada pocos minutos.
- Teléfono enchufado durante la sesión.

## Diseño
- Fondo oscuro, texto grande legible a 2 metros, colores por estado (verde/ámbar/rojo).
- Números grandes arriba, detalle al tocar.

## Gadgets
- Reloj y fecha locales (sin red).
- Clima: Open-Meteo consultado desde el teléfono cada 15–30 min.

## Estados de conexión
- Conectado, Reconectando, Equipo apagado/suspendido (mostrar último dato con marca de tiempo).
- Si la conexión se corta durante una sesión, el agente sigue guardando y la app recupera el informe al reconectar.

## Implementación 0.2.0

La navegación actual tiene tres destinos: Panel, Procesos y Sesiones. El panel
funciona en vertical y horizontal con desplazamiento, sin imponer orientación.
Muestra gráficas recientes CPU/RAM, CPU por núcleo, lectura/escritura, bajada/subida,
batería y primer sensor térmico disponible con su etiqueta. Ausencias: —.

Procesos permite búsqueda y ordenar los 20 grupos de mayor memoria por CPU/RAM.
Sesiones permite iniciar/detener, historial de 30 informes y exportación al PC.
La pantalla se mantiene activa mediante una bandera Android opcional mientras
haya conexión y la ventana sea visible; no se añadió wakelock_plus ni servicio
CPU. Modo inmersivo, brillo automático, gadgets y sugerencias aún no están hechos.

El formulario USB aparece al estar desconectado, con token vacío y URL avanzada.
Datos en vivo se retiran al perder conexión; los reintentos son automáticos y
acotados. Un token rechazado requiere corregirlo; no se vuelve a intentar solo.


## Gráficas 0.3.0

Cuatro destinos: Panel, Gráficas, Procesos y Sesiones. Se sustituyen las
minicurvas del panel por gráficas amplias con ejes, colores de serie, media/pico
por ventana y selección táctil de muestras. Ventanas de 1 y 5 minutos con límite
650 puntos, timestamps de recepción en el teléfono. Cortes >3 s y muestras
nulas se dibujan como huecos. CPU/RAM comparten 0–100 %; pares de disco/red
comparten autoescala explícita. Barras de procesos comparan RAM entre los grupos
visibles, sin atribuir un porcentaje del total del equipo. Agente/protocolo sin cambios.


## Distribución horizontal 0.4.0

Android mantiene sensorLandscape, en ambos sentidos, sin cambiar la rotación
configurada del dispositivo. Sustituye la orientación libre de 0.3.0 (D-011).

- Navegación lateral, cabecera de 44 dp y SafeArea para cámara/barras del sistema.
- Panel: seis métricas en una cuadrícula 3×2, actividad por núcleo y curva CPU/RAM.
- Gráficas: tres tarjetas simultáneas con leyendas compactas y ejes compartidos.
- Procesos: filtro lateral y tarjetas en columnas; lista desplazable independiente.
- Sesiones: control a la izquierda e historial a la derecha; informes desplazables.
- Texto del sistema ampliado o teclado: disposición desplazable para conservar
  legibilidad y controles. No se reduce globalmente la escala de accesibilidad.

Las dimensiones y márgenes del Samsung se cubren con tests de layout; la prueba
física se registra en PROGRESS. Agente y conexión Windows conservan su contrato.

## Navegación y apariencia 0.4.1

El tema oscuro fijo se sustituye por Sistema/Claro/Oscuro en menú ⋮, con
preferencia nativa Android persistente. Curvas, rejilla y valores usan colores
legibles según tema. Pantalla activa usa un icono de pantalla independiente.
El informe mantiene título y X fuera de su lista desplazable. Atrás cierra
primero el modal; desde otros destinos vuelve al Panel y desde allí ofrece salir.
Salir desconecta el cliente sin terminar una grabación del computador.
Grabar sesión sustituye a Iniciar sesión para aclarar su finalidad opcional.

## Selector visual de tema 0.4.2

Tres iconos directamente en cabecera: sol (claro), luna (oscuro) y A (sistema).
Selección resaltada, etiquetas accesibles y ayuda al mantener pulsado. Sustituye
las entradas de tema del menú ⋮; este conserva la salida. Mantiene persistencia,
conexión y disposición horizontal. El control de pantalla activa sigue separado.

## Cierre individual 0.5.0

En Procesos, X de tarjeta abre un detalle desplazable con título/cierre fijos.
Cada miembro muestra nombre, PID, ejecutable, protección/motivo y X individual.
Confirmación con identidad validada por el agente, Cancelar/Finalizar/Forzar cierre,
aviso de cambios sin guardar y plazo 30 s. Resultado explícito; cierre no se
reintenta solo. Si el agente carece de process_actions se pide actualizarlo.

## Gráficas ampliadas 0.6.0

Tocar la tarjeta/curva en Panel o Gráficas abre una ruta sin navegación lateral.
Misma conexión, historial, curvas y política de huecos; datos siguen en vivo.
Cabecera con X fija y selector 1/5 min; Atrás vuelve al origen. Selección de valor
por toque/arrastre dentro de la vista ampliada; pulsación larga limpia selección.
Texto grande/altura pequeña permiten desplazamiento conservando cabecera accesible.
SafeArea protege cámara/barras; no se modifica el modo inmersivo global.
