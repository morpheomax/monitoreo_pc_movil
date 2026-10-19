"""Metricas comunes para macOS y Windows.

Los colectores especificos de sensores se agregaran despues. Este modulo no
debe inventar valores: un sensor ausente se representa con ``None`` y ``reason``.
"""

from __future__ import annotations

import platform
import os
from pathlib import Path
import time
from collections import defaultdict
from typing import Any, Dict, Iterable, Optional, Tuple

import psutil

from actions.processes import ProcessPolicy

_POLICY = None


def bytes_per_second(current: Optional[int], previous: Optional[int], elapsed: float) -> Optional[float]:
    """Calcula una tasa usando el intervalo real entre muestras."""
    if current is None or previous is None or elapsed <= 0:
        return None
    return max(0.0, (current - previous) / elapsed)


def normalize_process_name(name: Optional[str]) -> str:
    """Normaliza etiquetas de grupos sin usarlas como identidad para acciones."""
    value = name or "?"
    for suffix in (" Helper (Renderer).exe", " Helper (GPU).exe", ".exe", " Helper (Renderer)", " Helper (GPU)", " Helper"):
        if value.casefold().endswith(suffix.casefold()):
            return value[:-len(suffix)]
    return value


def group_processes(processes: Iterable[Dict[str, Any]], top: int = 20) -> list[Dict[str, Any]]:
    """Agrupa para presentación; conserva la identidad individual de cada miembro."""
    groups: Dict[str, Dict[str, Any]] = defaultdict(
        lambda: {"app": "", "cpu": 0.0, "mem": 0, "pids": [], "paths": [], "count": 0, "members": []}
    )
    for process in processes:
        name = normalize_process_name(process.get("name"))
        executable = process.get("exe") or ""
        if ".app/" in executable:
            # Usar el bundle exterior une helpers anidados sin depender del nombre Chromium.
            name = executable.split(".app/", 1)[0].rsplit("/", 1)[-1]
        group = groups[name]
        group["app"] = name
        group["cpu"] += float(process.get("cpu", 0.0) or 0.0)
        group["mem"] += int(process.get("mem", 0) or 0)
        group["count"] += 1
        group["members"].append({key: process.get(key) for key in
                                 ("pid", "name", "exe", "create_time", "can_terminate", "blocked_reason")})
        if process.get("pid") is not None:
            group["pids"].append(process["pid"])
        if process.get("exe"):
            group["paths"].append(process["exe"])
    return sorted(groups.values(), key=lambda item: item["mem"], reverse=True)[:top]


def _process_rows() -> list[Dict[str, Any]]:
    global _POLICY
    if _POLICY is None:
        _POLICY = ProcessPolicy()
    rows = []
    for process in psutil.process_iter(["name", "cpu_percent", "memory_info", "exe", "create_time", "username"]):
        try:
            info = process.info
            memory = info.get("memory_info")
            reason = _POLICY.reason({**info, "pid": process.pid})
            rows.append(
                {
                    "name": info.get("name"),
                    "cpu": info.get("cpu_percent") or 0.0,
                    "mem": memory.rss if memory else 0,
                    "pid": process.pid,
                    "exe": info.get("exe"),
                    "create_time": info.get("create_time"),
                    "can_terminate": reason is None,
                    "blocked_reason": reason,
                }
            )
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue
    return rows


def _temperature_payload(temperature_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    if not temperature_data:
        return None
    result = {}
    for sensor, entries in temperature_data.items():
        result[sensor] = [
            {
                "label": getattr(entry, "label", ""),
                "current": getattr(entry, "current", None),
                "high": getattr(entry, "high", None),
                "critical": getattr(entry, "critical", None),
            }
            for entry in entries
        ]
    return result


def collect_snapshot(previous: Optional[Dict[str, Any]] = None, include_processes: bool = True) -> Dict[str, Any]:
    """Devuelve un snapshot JSON-compatible para el futuro protocolo v1."""
    now = time.time()
    previous = previous or {}
    previous_counters = previous.get("_counters", previous)
    elapsed = now - previous_counters.get("ts", previous.get("ts", now))
    per_core = psutil.cpu_percent(None, percpu=True)
    memory = psutil.virtual_memory()
    swap = psutil.swap_memory()
    disk = psutil.disk_io_counters()
    network = psutil.net_io_counters()
    battery = psutil.sensors_battery()
    temperatures = getattr(psutil, "sensors_temperatures", None)
    temperature_data = temperatures() if temperatures else {}
    temperature_payload = _temperature_payload(temperature_data)
    # En Windows '/' depende de la unidad actual; usar la unidad del sistema.
    system_root = os.environ.get("SystemDrive", Path.home().anchor) + "\\" if platform.system() == "Windows" else "/"
    disk_usage = psutil.disk_usage(system_root)

    disk_read = getattr(disk, "read_bytes", None) if disk else None
    disk_write = getattr(disk, "write_bytes", None) if disk else None
    net_received = getattr(network, "bytes_recv", None) if network else None
    net_sent = getattr(network, "bytes_sent", None) if network else None

    return {
        "v": 1,
        "type": "metrics",
        "ts": int(now),
        "cpu": {"total": sum(per_core) / len(per_core) if per_core and previous else None,
                "per_core": per_core if previous else [], "reason": None if previous else "warming_up"},
        "mem": {
            "used": memory.used,
            "total": memory.total,
            "swap_used": swap.used,
            "pressure": None,
            "pressure_reason": "platform_adapter_pending",
        },
        "disk": {
            "read_bps": bytes_per_second(disk_read, previous_counters.get("disk_read"), elapsed),
            "write_bps": bytes_per_second(disk_write, previous_counters.get("disk_write"), elapsed),
            "used": disk_usage.used,
            "total": disk_usage.total,
        },
        "net": {
            "down_bps": bytes_per_second(net_received, previous_counters.get("net_received"), elapsed),
            "up_bps": bytes_per_second(net_sent, previous_counters.get("net_sent"), elapsed),
        },
        "battery": {
            "percent": battery.percent if battery else None,
            "charging": battery.power_plugged if battery else None,
            "reason": None if battery else "no_battery_sensor",
        },
        "temps": {"available": bool(temperature_payload), "data": temperature_payload, "reason": None if temperature_payload else "platform_adapter_pending"},
        "processes": group_processes(_process_rows()) if include_processes else previous.get("processes", []),
        "host": {"os": platform.system(), "os_version": platform.release(), "machine": platform.machine()},
        "_counters": {"disk_read": disk_read, "disk_write": disk_write, "net_received": net_received, "net_sent": net_sent, "ts": now},
    }
