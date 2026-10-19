# Roadmap revisado — 2026-10-18

Núcleo y sesiones primero; inteligencia después. Windows se valida en cada
incremento del agente, en lugar de esperar una fase tardía. D-006 documenta el cambio.

## 1. Consolidar agente + Android por USB — en curso

Implementado: métricas comunes, WebSocket autenticado, dashboard y procesos
agrupados; APK y validación física Mac registrados. Ahora hay lanzadores comunes
para Windows y Mac con entorno aislado, diagnóstico y reenvío USB.

Para cerrar:
- [x] Probar el nuevo lanzador en Mac con Android físico y reparación USB sin reinicio.
- [x] Copiar las fuentes a Windows, instalar Python y Platform-Tools, abrir el
  lanzador y ver CPU/RAM reales en el mismo teléfono, sin Flutter en Windows.
  El usuario informó instalación y funcionamiento correctos el 2026-10-18.
  La conexión rápida de 0.7.0/0.4.0 requiere una nueva prueba allí.
- [ ] Medir CPU y RAM del agente en ambos sistemas durante 10 minutos en reposo
  y transmitiendo. Objetivo en reposo: <1 % CPU y <60 MB RAM.
- [x] Separar el cliente WebSocket de la pantalla; reconexión con espera progresiva,
  límite del handshake y cancelación al desconectar. Mostrar datos obsoletos como tales.
- [x] Validar pérdida/restauración del reenvío USB, rechazo de token y cierre limpio en Mac + Samsung. Falta cable físico y Windows.
- [x] Alinear el contrato documentado con mensajes reales y cubrirlo con tests.
- [ ] Decidir adaptadores de sensores; lo ausente continúa en `null` con motivo.

**Listo cuando:** una persona puede iniciar desde las instrucciones en ambos
sistemas, conectar el teléfono y mantener el dashboard estable sin emuladores.

## 2. Sesiones, historial e informe — implementado, aceptación prolongada pendiente

Implementado en 0.2.0: muestreador compartido, SQLite local, sesiones que continúan
sin teléfono, recuperación como interrumpidas, informe, historial, CSV y retención.
Tests y sesión real en Samsung de 2 min 42 s / 162 muestras verificados.
Pendiente: prueba de 1–2 horas, consumo durante 10 minutos y Windows/Power BI.

Diseño y criterios originales de aceptación:

- Extraer un muestreador compartido para clientes e historial: métricas cada 1 s,
  procesos cada 3 s; sin cliente ni sesión, no recolectar.
- SQLite en una carpeta de datos del usuario; una sesión pertenece al equipo.
- `session_start`, `session_stop`, recuperación tras interrupción y persistencia
  aunque el cable se desconecte durante una sesión activa.
- Informe con medias, picos y consumidores; CSV, retención y agregación de docs/08.
- Tests de cálculos, retención y recuperación. No inferir throttling solo por temperatura.

**Listo cuando:** sesión real de 1–2 horas, reconexión del teléfono sin pérdida
del registro, informe verificable y CSV que se puede abrir en Power BI.

## 3. Gestión segura de procesos — cierre individual implementado; aceptación Windows pendiente

Siguiente mejora solicitada: **Cerrar aplicación completa** desde la tarjeta,
con una confirmación, identidad de aplicación/relaciones y resultado por PID.
Conservar protegidos, permisos, auditoría y validación de identidad. No cerrar por
nombre ni prometer guardado automático: `terminate` en Windows es forzado.
Todavía no implementado; la conexión rápida USB se completa primero.

- [x] Agrupación con miembros PID/ruta/creación; el nombre agrupado es solo presentación.
- [x] Módulo `actions/`: token, confirmación, PID + ejecutable + identidad temporal,
  permisos del usuario y lista de protegidos; registro de la acción en sesión.
- [x] Ordenación por CPU/memoria y resultados de cierre claros.
- [x] Tests de procesos protegidos, PID reutilizado, proceso inexistente y rechazo.
- [ ] Validación física de cierres y protegidos en Windows.
- Cierre individual desde Procesos (agente 0.3.0/app 0.5.0), con SIGTERM o forzado
  explícito, auditado en SQLite. Sin cierre de grupos completos ni restauración.

**Listo cuando:** se cierra una app permitida y se rechazan acciones contra
procesos críticos o cuya identidad haya cambiado, en Windows y Mac.

## 4. Sugerencias y modo foco — pendiente

- Parser y reglas YAML con tests; perfiles Datos/Desarrollo y explicaciones.
- Guardar nombre, ejecutable y argumentos antes de cerrar para poder reabrir.
- Validar cada cierre con el mismo módulo de acciones, incluyendo el cierre en bloque.

**Listo cuando:** recomendaciones útiles y deshacer comprobado en ambos sistemas.

## 5. Uso prolongado y distribución — pendiente

- Pantalla encendida, modo inmersivo y consumo/brillo del teléfono.
- Empaquetar el agente por plataforma para usarlo sin Python externo; diagnosticar
  ADB y permisos, desinstalación y actualizaciones. Bandeja e inicio opcional.
- Probar instalación en un Windows y un Mac limpios con Android físico.

**Listo cuando:** instalación y primer panel en menos de 5 minutos, sin herramientas
de desarrollo ni comandos manuales. Los lanzadores actuales son un paso intermedio.

## 6. Wi-Fi y emparejamiento — pendiente

TLS, QR con huella, tokens por dispositivo y revocación. Sin acceso desde internet.
**Listo cuando:** conexión local sin cable, con autenticación y validación del servidor.

## Después del núcleo

Gadgets (reloj/clima), iOS por Wi-Fi, línea base, fugas de memoria, notificaciones,
multi-equipo, SQL Server de solo lectura y otros elementos de backlog. No bloquean
la validación del agente, las sesiones ni el informe.
