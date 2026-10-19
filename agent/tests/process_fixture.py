"""Subproceso desechable con arranque confirmado, portable entre Windows y Mac."""

import asyncio
import subprocess
import sys

import psutil


async def start_worker():
    child = psutil.Popen(
        [sys.executable, "-u", "-c", "import time; print('ready', flush=True); time.sleep(60)"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    try:
        # Python framework en macOS puede cambiar de ejecutable durante el arranque.
        # Capturar identidad antes de 'ready' probaría una carrera ajena al cierre.
        ready = await asyncio.wait_for(asyncio.to_thread(child.stdout.readline), timeout=5)
        if ready.strip() != "ready":
            raise RuntimeError("El proceso de prueba no pudo iniciar.")
        return child
    except BaseException:
        if child.is_running():
            child.kill()
        child.wait(timeout=3)
        raise
    finally:
        child.stdout.close()
