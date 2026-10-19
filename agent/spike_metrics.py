#!/usr/bin/env python3
"""
Fase 0 - Spike de métricas.
Imprime CPU, RAM, disco, red, batería y top de procesos agrupados por app.
También mide el consumo del propio script (objetivo: <1 % CPU, <60 MB RAM).

Uso:
    python spike_metrics.py                    # 30 s, top 10
    python spike_metrics.py --seconds 60 --top 8
"""
import argparse
import platform
import time
from collections import defaultdict

import psutil

GB = 1024 ** 3


def fmt_bytes(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(n) < 1024:
            return f"{n:6.1f} {unit}"
        n /= 1024
    return f"{n:6.1f} PB"


def app_name(proc_name: str) -> str:
    """Agrupación simple por nombre. Se refinará con rules/processes.yaml."""
    name = proc_name or "?"
    for suffix in (".exe", " Helper", " Helper (Renderer)", " Helper (GPU)"):
        name = name.replace(suffix, "")
    return name


def grouped_processes(top: int):
    groups = defaultdict(lambda: {"cpu": 0.0, "mem": 0, "count": 0})
    for p in psutil.process_iter(["name", "cpu_percent", "memory_info"]):
        try:
            info = p.info
            mem = info["memory_info"].rss if info["memory_info"] else 0
            g = groups[app_name(info["name"])]
            g["cpu"] += info["cpu_percent"] or 0.0
            g["mem"] += mem
            g["count"] += 1
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue
    by_mem = sorted(groups.items(), key=lambda kv: kv[1]["mem"], reverse=True)[:top]
    by_cpu = sorted(groups.items(), key=lambda kv: kv[1]["cpu"], reverse=True)[:top]
    return by_mem, by_cpu


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=int, default=30)
    ap.add_argument("--top", type=int, default=10)
    args = ap.parse_args()

    print(f"Sistema: {platform.system()} {platform.release()} | {platform.machine()}")
    print(f"Núcleos lógicos: {psutil.cpu_count()} | RAM total: {psutil.virtual_memory().total / GB:.1f} GB")

    me = psutil.Process()
    me.cpu_percent(None)
    psutil.cpu_percent(None, percpu=True)
    for p in psutil.process_iter():          # "cebar" cpu_percent de cada proceso
        try:
            p.cpu_percent(None)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

    prev_disk = psutil.disk_io_counters()
    prev_net = psutil.net_io_counters()
    prev_t = time.time()

    for _ in range(args.seconds):
        time.sleep(1)
        now = time.time()
        dt = now - prev_t                    # intervalo real, no "1 s" supuesto
        prev_t = now

        per_core = psutil.cpu_percent(None, percpu=True)
        cpu_total = sum(per_core) / len(per_core)
        vm = psutil.virtual_memory()
        sw = psutil.swap_memory()
        disk = psutil.disk_io_counters()
        net = psutil.net_io_counters()

        r_bps = (disk.read_bytes - prev_disk.read_bytes) / dt if disk else 0
        w_bps = (disk.write_bytes - prev_disk.write_bytes) / dt if disk else 0
        d_bps = (net.bytes_recv - prev_net.bytes_recv) / dt
        u_bps = (net.bytes_sent - prev_net.bytes_sent) / dt
        prev_disk, prev_net = disk, net

        batt = psutil.sensors_battery()
        temps = getattr(psutil, "sensors_temperatures", None)
        temp_info = temps() if temps else {}

        print("\n" + "=" * 70)
        print(f"CPU {cpu_total:5.1f} %  | núcleos: " + " ".join(f"{c:4.0f}" for c in per_core))
        print(f"RAM {vm.percent:5.1f} % ({vm.used / GB:.1f}/{vm.total / GB:.1f} GB) | swap {sw.used / GB:.1f} GB")
        print(f"DISCO leer {fmt_bytes(r_bps)}/s escribir {fmt_bytes(w_bps)}/s | libre {psutil.disk_usage('/').free / GB:.0f} GB")
        print(f"RED   bajada {fmt_bytes(d_bps)}/s subida {fmt_bytes(u_bps)}/s")
        if batt:
            print(f"BATERÍA {batt.percent:.0f} % {'(cargando)' if batt.power_plugged else ''}")
        print(f"TEMPERATURAS (psutil): {temp_info if temp_info else 'no disponible en este sistema'}")

        by_mem, by_cpu = grouped_processes(args.top)
        print(f"\nTop {args.top} por MEMORIA")
        for name, g in by_mem:
            print(f"  {name[:32]:32} {fmt_bytes(g['mem'])}  CPU {g['cpu']:5.1f} %  ({g['count']} proc.)")
        print(f"Top {args.top} por CPU")
        for name, g in by_cpu:
            print(f"  {name[:32]:32} CPU {g['cpu']:5.1f} %  {fmt_bytes(g['mem'])}  ({g['count']} proc.)")

        print(f"\n[este script] CPU {me.cpu_percent(None):4.1f} % | RAM {me.memory_info().rss / (1024 * 1024):.0f} MB")


if __name__ == "__main__":
    main()
