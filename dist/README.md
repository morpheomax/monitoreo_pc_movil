# Entrega PC Monitor — Android 0.7.0 / agente 0.4.0

1. Instala/actualiza el teléfono con [APK ARM64](pcmonitor-android-0.7.0-arm64.apk)
   siguiendo el [README principal](../README.md). Samsung de desarrollo ya instalado.
2. Descomprime [agente Windows/Mac](pcmonitor-agent-0.4.0.zip) en cada computador.
   Incluye Start Windows.cmd, Start Mac.command y LEEME.md con pasos completos.
3. Prepara Python 3.11+ y Platform-Tools del SO. Autoriza USB y abre su lanzador.
4. Android abre la confirmación USB: revisa equipo/sistema y pulsa **Conectar**;
   el token llega automáticamente. Actualiza APK y agente para habilitarlo.
   Copiar el token sigue disponible como alternativa. **No hay cuenta**;
   Grabar sesión solo inicia el registro histórico.

Alternativa Windows: [ZIP específico](pcmonitor-windows-agent-0.4.0.zip). Basta uno
de los paquetes del agente. APK y herramientas de terceros se entregan/instalan
por separado; los ZIP no incluyen entornos virtuales, tokens ni historial.

[SHA256SUMS.txt](SHA256SUMS.txt) permite comprobar integridad. Por ejemplo:

```powershell
Get-FileHash .\pcmonitor-android-0.7.0-arm64.apk -Algorithm SHA256
```

```bash
shasum -a 256 pcmonitor-android-0.7.0-arm64.apk
```

Comparar con el valor del manifiesto. El ZIP antiguo 0.2.0 es histórico y no
habilita cierres: usar 0.4.0. El APK es ARM64/API 24+ y usa firma de desarrollo.
Uso básico Windows confirmado por el usuario; conexión rápida nueva pendiente allí.
