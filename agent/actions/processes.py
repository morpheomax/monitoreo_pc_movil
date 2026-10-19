"""Cierre de un PID identificado; nunca resolver objetivos por nombre de grupo."""

import asyncio
import math
import ntpath
import os
import platform
import secrets
import time

import psutil


PROTECTED_NAMES = frozenset({
    "system", "system idle process", "registry", "memory compression",
    "smss.exe", "csrss.exe", "wininit.exe", "winlogon.exe", "services.exe",
    "lsass.exe", "lsaiso.exe", "svchost.exe", "dwm.exe", "explorer.exe",
    "sihost.exe", "fontdrvhost.exe", "securityhealthservice.exe", "msmpeng.exe",
    "launchd", "kernel_task", "windowserver", "loginwindow", "securityd",
    "watchdogd", "runningboardd", "powerd", "logd", "opendirectoryd",
    "adb", "adb.exe", "pcmonitor", "pcmonitor.exe",
})


class ActionError(ValueError):
    pass


class ProcessPolicy:
    def __init__(self):
        self.owner = ""
        self.protected_pids = {0, 1, 4, os.getpid()}
        self.system = platform.system()
        self.ready = False
        try:
            current = psutil.Process()
            self.owner = current.username()
            self.protected_pids.update(p.pid for p in current.parents())
            self.ready = True
        except (psutil.Error, OSError):
            # Si no se puede construir la protección, conservar monitoreo sin habilitar cierres.
            pass

    def reason(self, info):
        if not getattr(self, "ready", True):
            return "No se pudo verificar la protección del agente; cierre deshabilitado."
        if info.get("pid") in self.protected_pids:
            return "Proceso del sistema, agente o su cadena de ejecución."
        if (info.get("name") or "").casefold() in PROTECTED_NAMES:
            return "Proceso protegido del sistema o de la conexión USB."
        exe = info.get("exe")
        created = info.get("create_time")
        if (not isinstance(exe, str) or not exe or not isinstance(created, (int, float))
                or isinstance(created, bool) or not math.isfinite(created) or created <= 0):
            return "No se puede verificar la ruta o identidad del proceso."
        if (info.get("username") or "").casefold() != self.owner.casefold():
            return "Pertenece a otro usuario o no se puede verificar su propietario."
        if self.system == "Windows":
            path = ntpath.normcase(ntpath.normpath(exe))
            system_dir = ntpath.normcase(ntpath.normpath(os.environ.get("SystemRoot", r"C:\Windows")))
            if path == system_dir or path.startswith(system_dir + "\\"):
                return "Ejecutable protegido de Windows."
        elif exe.startswith(("/System/", "/usr/", "/sbin/", "/bin/")):
            return "Ejecutable protegido del sistema."
        return None

    def validate(self, identity):
        if not isinstance(identity, dict):
            raise ActionError("Falta la identidad del proceso.")
        pid = identity.get("pid")
        created = identity.get("create_time")
        exe = identity.get("exe")
        if (type(pid) is not int or pid <= 0 or not isinstance(exe, str) or not exe
                or type(created) not in (int, float) or not math.isfinite(created)):
            raise ActionError("Identidad inválida. Actualiza la lista de procesos.")
        try:
            process = psutil.Process(pid)
            # No usar process_iter ni oneshot aquí: releer la identidad justo antes de actuar.
            info = {"pid": pid, "name": process.name(), "exe": process.exe(),
                    "create_time": process.create_time(), "username": process.username()}
            if info["exe"] != exe or info["create_time"] != created or not process.is_running():
                raise ActionError("El proceso cambió. Actualiza la lista; no se cerró ningún proceso.")
            reason = self.reason(info)
            if reason:
                raise ActionError(reason)
            return process, info
        except psutil.NoSuchProcess:
            raise ActionError("El proceso ya terminó.") from None
        except psutil.AccessDenied:
            raise ActionError("El sistema no permite verificar o cerrar este proceso.") from None


class ProcessActions:
    """Tickets breves, de un solo uso y exclusivos de una conexión autenticada."""
    def __init__(self, token, policy, audit):
        self.token = token
        self.policy = policy
        self.audit = audit
        self.tickets = {}
        self.last_action = float("-inf")

    def authorize(self, token):
        if not isinstance(token, str) or not secrets.compare_digest(token.encode(), self.token.encode()):
            raise ActionError("Token inválido para gestionar procesos.")

    def prepare(self, token, identity):
        self.authorize(token)
        now = time.monotonic()
        self.tickets = {key: value for key, value in self.tickets.items() if value[0] > now}
        if len(self.tickets) >= 8:
            raise ActionError("Demasiadas confirmaciones pendientes. Espera unos segundos.")
        _, info = self.policy.validate(identity)
        ticket = secrets.token_urlsafe(24)
        self.tickets[ticket] = (now + 30, info)
        return {"ticket": ticket, "process": {k: info[k] for k in ("pid", "name", "exe", "create_time")},
                "expires_in_s": 30}

    async def terminate(self, token, ticket, confirmed, force):
        self.authorize(token)
        if confirmed is not True or type(force) is not bool:
            raise ActionError("Se requiere confirmación explícita y un modo de cierre válido.")
        pending = self.tickets.pop(ticket, None) if isinstance(ticket, str) else None
        if pending is None or pending[0] <= time.monotonic():
            raise ActionError("La confirmación venció o ya se utilizó. Abre nuevamente el proceso.")
        if time.monotonic() - self.last_action < 1:
            raise ActionError("Espera un segundo antes de enviar otro cierre.")
        self.last_action = time.monotonic()
        info = pending[1]
        action = "kill" if force else "terminate"
        try:
            process, info = self.policy.validate(info)
            # Guardar antes de enviar la señal; si SQLite falla, no ejecutar la acción.
            self.audit(info, action, "requested", "Confirmado desde Android")
            if force:
                process.kill()
            else:
                process.terminate()
            self.audit(info, action, "signal_sent", "Señal enviada al PID verificado")
            # Espera asíncrona breve: no bloquear métricas ni SQLite con wait().
            for _ in range(10):
                if not process.is_running() or process.status() == psutil.STATUS_ZOMBIE:
                    self.audit(info, action, "terminated", "Proceso finalizado")
                    return {"status": "terminated", "pid": info["pid"], "message": "Proceso finalizado."}
                await asyncio.sleep(.15)
            self.audit(info, action, "still_running", "Sigue activo después de enviar la señal")
            return {"status": "still_running", "pid": info["pid"],
                    "message": "La señal fue enviada, pero el proceso sigue activo. Puedes volver a confirmar un cierre forzado."}
        except psutil.NoSuchProcess:
            self.audit(info, action, "terminated", "El proceso ya terminó")
            return {"status": "terminated", "pid": info["pid"], "message": "El proceso ya terminó."}
        except (ActionError, psutil.AccessDenied) as error:
            message = str(error) if isinstance(error, ActionError) else "Permiso de cierre denegado por el sistema."
            self.audit(info, action, "rejected", message)
            raise ActionError(message) from None
