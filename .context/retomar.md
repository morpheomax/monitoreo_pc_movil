# Retomar PC Monitor — cierre del 18 de octubre de 2026

## Punto de partida

Único repositorio para código, documentación, contexto, avances y futuras publicaciones: https://github.com/morpheomax/monitoreo_pc_movil.git . No usar otros repositorios para este proyecto; las menciones anteriores solo documentan la migración histórica.

- Desarrollo en pausa a petición del usuario. Probará la app del 19 al 25 de
  octubre de 2026 y luego compartirá su experiencia. No hay recordatorio programado.
- Workspace: `/Users/maximilianosandoval/Documents/Innext_Solutions/appmoviles/monitorpc`.
- Único repositorio vigente: https://github.com/morpheomax/monitoreo_pc_movil.git .
  Código en raíz, rama main sigue origin/main; ya no hay que integrar en otro clon.
- El repositorio anterior monitoreo_Fitflow quedó **sin archivos en main**, por
  orden posterior explícita, commit29a4d50. Su historial se conserva. No restaurar
  ni publicar allí PC Monitor o Fitflow: el usuario subirá el proyecto correcto.
- D-019 sustituyó D-017; D-020 registra el vaciado posterior. Las entradas anteriores
  en PROGRESS y memoria son históricas; este documento describe el estado vigente.

## Entrega actual y uso

- Android0.7.0+9, APK ARM64/API24+, versionCode2009. Última instalación comprobada
  en Samsung SM-A156M. Firma de desarrollo; actualizar con la misma firma y -r.
- Paquete agente0.4.0 para Windows/macOS, Python3.11+ y Platform-Tools externos.
  dist contiene APK, ZIP común/Windows y SHA256SUMS. No exige Flutter para usarlo.
- Arranque: USB autorizado/desbloqueado → Start Windows.cmd o Start Mac.command →
  revisar nombre/SO en Android → Conectar. Token transferido sin escribirlo;
  nonce de un uso/90s por loopback/reverse. Sin cuenta ni contraseña guardada.
- Manual sigue disponible; --manual-connection omite abrir Android.
  --repair-usb repara el enlace sin reiniciar token/agente/grabación.
- Se trabaja con permisos normales. Controlador USB Windows podría necesitar
  administrador al instalarse; no elevar toda la app para cerrar procesos.

## Funciones existentes

- Panel horizontal en ambos sentidos, SafeArea y adaptación al texto/teclado.
- Panel, Gráficas, Procesos y Sesiones; sol/luna/A persistentes, pantalla activa,
  salida explícita, informes con X y navegación Atrás.
- CPU/RAM, disco/red, batería y sensores disponibles; ausentes null/motivo.
  Gráficas1/5min; toque amplía, X/Atrás regresa, datos siguen en vivo.
- Sesión opcional en SQLite del PC, informes/CSV y retención7d/agregados por minuto.
  Desconectar Android no detiene grabación; Finalizar genera informe. Cerrar el
  agente deja recuperación interrumpida. Datos no se sincronizan entre equipos.
- Cierre individual por PID desde Procesos, con token, protegido/propietario,
  PID+ejecutable+creación, ticket30s/un uso, confirmación y auditoría SQLite.
  Sin elevación ni escalado/reintento automático. En Windows terminate es forzado.

## Evidencia y límites

- Usuario confirmó instalación/funcionamiento básico en Windows.
- Mac+Samsung: conexión USB rápida y recepción de métricas reales; cancelar una
  segunda solicitud conserva conexión. Temas, gráficas ampliadas, sesiones/CSV,
  reconexión y cierres probados previamente con procesos desechables.
- Última validación:29 Flutter, analyze limpio,24 agente,9 arranque.
  CI del repositorio nuevo39186773883 aprobada Windows/macOS con tests y paquetes.
  https://github.com/morpheomax/monitoreo_pc_movil/actions/runs/39186773883
- Faltan evidencia física de conexión rápida nueva/cierres en Windows, sesiones
  reales1–2h, CSV/PowerBI y consumo prolongado10min. Objetivo reposo <1%CPU/<60MB;
  mediciones breves anteriores no cierran esa aceptación.
- No implementados: cierre completo por aplicación, Wi-Fi/QR/TLS, sensores
  avanzados, sugerencias/modo foco e instaladores sin Python externo.

## Primera acción al regresar

1. Leer este documento, README, arquitectura, decisiones y último PROGRESS;
   comprobar git status/remoto antes de cambiar archivos.
2. Recoger resultados de la semana: SO, versión, pasos, esperado/observado,
   frecuencia y duración; separar fallos reproducibles de mejoras visuales.
3. Corregir bloqueos/errores antes de ampliar funciones. Próxima mejora solicitada:
   **Cerrar aplicación completa** desde tarjeta y una confirmación; aún pendiente.
   Agrupar por identidad/relaciones, validar cada PID, conservar protegidos y
   auditoría, informar cierres parciales. Nunca cerrar solo por nombre ni prometer
   guardado de cambios con terminate en Windows.
4. Acordar prioridades según experiencia; después considerar grabación más visible,
   comparación de sesiones/alertas e instalador. Mantener agente liviano.
5. Actualizar README/contexto/PROGRESS; decisiones con tradeoffs al registro.

No guardar tokens, claves, sesiones, SQLite, SDK ni entornos en Git. El cierre de
hoy pausa el desarrollo, sin ordenar apagar agentes o detener grabaciones activas.
