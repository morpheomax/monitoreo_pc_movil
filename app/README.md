# App Android — 0.6.0

Instalada y probada en Samsung SM-A156M físico. El mismo APK sirve con Mac o
Windows; el agente y el historial viven en el computador.

## Instalación y credenciales

El APK listo está en `../dist/pcmonitor-android-0.6.0-arm64.apk`. Las instrucciones
para instalarlo por ADB y preparar el computador están en el [README principal](../README.md).
El paquete del agente para ambos sistemas es `../dist/pcmonitor-agent-0.3.0.zip`.

**No hay usuario ni contraseña de cuenta.** Copia el **Token:** que genera/muestra
el lanzador en el computador al campo **Token del computador** de la app. Cambia
al reiniciar el agente. Grabar sesión no pide otra clave: inicia el registro de métricas.
No guardes tokens reales en documentación o archivos del proyecto.

## Uso

Seguir [README](../README.md) o la [guía Windows](../docs/10-ejecutar-windows.md).
Iniciar agente, escribir su token en Panel y conectar a `ws://127.0.0.1:8765`.
El token no se guarda al cerrar la app. Colocar el teléfono en horizontal:
Android mantiene ambos sentidos mediante sensorLandscape, sin ajustes globales.

- Panel horizontal: seis tarjetas, núcleos y curva CPU/RAM en la misma pantalla.
- Navegación lateral y cabecera compacta; sesión y desconexión siempre accesibles.
- Gráficas: CPU/RAM, lectura/escritura y bajada/subida; ventanas de 1/5 minutos,
  ejes y escalas compartidas, media/pico y consulta táctil. En horizontal las tres
  curvas se muestran lado a lado. Hasta 650 puntos en
  memoria; no interpolar huecos de conexión ni suspensión.
- Tocar una gráfica abre una vista completa en vivo, con X fija/Atrás para volver.
  Consulta táctil y selector 1/5 min dentro de la vista ampliada.
- Procesos: top 20 por RAM, búsqueda, orden y barras relativas de memoria.
  X en tarjeta abre detalle; X por PID ofrece Finalizar/Forzar cierre y Cancelar.
  Protegidos bloqueados. Requiere capacidad process_actions del agente 0.3.0.
- Sesiones: iniciar/terminar, informe, historial y CSV en el computador.
- Reconexión automática con datos obsoletos retirados; token incorrecto detiene
  reintentos. Restaurar ADB con `--repair-usb` tras reconectar físicamente el cable.
- Pantalla encendida opcional mientras esté conectada y visible.
- Iconos de sol/luna/A en cabecera para claro/oscuro/sistema; selección resaltada
  y persistida. Menú ⋮ para Salir de la app.
- Informe con X fija; Atrás cierra informe, vuelve al Panel u ofrece salir.
- Grabar sesión es opcional para registrar histórico; salir no termina la grabación.

## Desarrollo

Flutter estándar: `dart:io` + ChangeNotifier, sin dependencias nuevas. Plataforma
Android ya generada; no volver a ejecutar `flutter create .`.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

APK ARM64 optimizado: 17.9 MB. Release usa todavía firma de desarrollo. Para
otros Android, compilar la ABI correspondiente. El APK dividido ARM64 de +8
instala versionCode 2008; conservar este esquema e incrementar build number en
actualizaciones. Preferir dispositivo físico.

`connection/monitor_controller.dart` contiene transporte/estado; `screens/`
contiene la UI. `models/metric_history.dart` mantiene la ventana temporal y
`widgets/metric_chart.dart` dibuja/consulta las curvas, con variante compacta;
`widgets/landscape_shell.dart` organiza navegación y cabecera. Texto grande y
teclado disponen de áreas desplazables para conservar los controles accesibles. El canal Android `pcmonitor/panel` controla la bandera de pantalla y la preferencia local de tema.
Cierre por PID disponible con agente 0.3.0; sugerencias, Wi-Fi e iOS pendientes.

SDK de desarrollo validado: Flutter 3.47.6 / Dart 3.13.5.
