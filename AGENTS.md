# AGENTS.md — PC Monitor

## Contexto
Proyecto: panel de monitoreo de PC (Windows y macOS) en un teléfono Android (luego iOS).
Desarrollador único, asistido por IA. Máquina de desarrollo: MacBook Air M3, 8 GB RAM
(cuidar el consumo: nada de emuladores pesados si se puede usar el teléfono físico).
Idioma de trabajo: español (código y commits en inglés, docs en español).

## Antes de escribir código
1. Leer `README.md`, `docs/01-arquitectura.md` y `.context/decisions.md`.
2. Leer el final de `PROGRESS.md` para saber dónde quedamos.
3. No cambiar una decisión de `.context/decisions.md` sin registrar la nueva decisión.

## Estructura prevista
```
pcmonitor/
├── agent/          # Python: recolecta métricas y expone WebSocket
│   ├── spike_metrics.py   # Fase 0
│   ├── collectors/ # cpu, mem, disk, net, temps (por plataforma)
│   ├── history/    # SQLite, sesiones, informe, exportación CSV
│   ├── actions/    # kill_process, etc. (siempre con validación)
│   ├── advisor/    # motor de sugerencias (reglas YAML)
│   └── server.py
├── app/            # Flutter (Android primero, iOS después)
├── rules/          # perfiles y base de conocimiento de procesos (YAML)
└── docs/
```

## Modelo de uso
El teléfono se usa en **sesiones de varias horas** durante trabajo intenso, no 24/7.
Todo lo que se mida durante una sesión se guarda en SQLite para el informe final (ver `docs/08-sesiones-e-historial.md`).

## Reglas de código
- El agente debe ser LIVIANO: objetivo < 1 % CPU y < 60 MB RAM en reposo. Medirlo.
- Un colector por plataforma detrás de una interfaz común; el resto del código no sabe en qué SO corre.
- Toda acción destructiva (matar proceso) pasa por `actions/` y valida: token válido, PID existente,
  proceso NO en lista de protegidos, confirmación del usuario.
- Nunca matar por nombre sin verificar PID + ruta del ejecutable.
- Protocolo versionado (`"v": 1`) en cada mensaje.
- Si un sensor no está disponible, devolver `null` y un motivo; nunca inventar valores.
- Tests para: parser de reglas, protegidos, agrupación de procesos, cálculo del informe de sesión.
- Historial: muestras agregadas (no guardar cada muestra de 1 s para siempre; ver política de retención en docs/08).
- Modo foco: antes de cerrar, guardar en la sesión la lista (nombre, ruta del ejecutable, argumentos) para poder reabrir.
- Prioridad de fases: núcleo y sesión primero; inteligencia después; backlog solo si el núcleo funciona.

## Flujo de trabajo
- Cada sesión termina agregando una entrada a `PROGRESS.md`.
- Decisiones con tradeoffs → `.context/decisions.md`.
- Commits pequeños, un tema por commit.

## Fuera de alcance (por ahora)
- Control remoto de escritorio, archivos, o cualquier cosa que no sea monitoreo y gestión de procesos.
- Acceso desde internet (solo red local o USB).
