#!/usr/bin/env python3
"""Arranque USB común: entorno aislado, diagnóstico y agente local."""

import argparse
import hashlib
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import venv

ROOT = Path(__file__).resolve().parent
AGENT = ROOT / "agent"


def find_adb(explicit=None):
    if explicit:
        candidate = Path(explicit).expanduser()
        if not candidate.is_file():
            raise RuntimeError(f"No existe ADB en {candidate}")
        return str(candidate)
    executable = "adb.exe" if os.name == "nt" else "adb"
    found = shutil.which("adb")
    if found:
        return found
    roots = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")]
    roots.append(str(ROOT))  # Platform-Tools junto al lanzador evita configurar PATH.
    if os.name == "nt":
        roots.append(str(Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData/Local")) / "Android/Sdk"))
    else:
        roots.extend([str(Path.home() / "Library/Android/sdk"), str(Path.home() / "Android/Sdk")])
    for root in filter(None, roots):
        candidate = Path(root) / "platform-tools" / executable
        if candidate.is_file():
            return str(candidate)
    raise RuntimeError("Falta Android Platform-Tools. Configura ANDROID_HOME o usa --adb RUTA_AL_ADB.")


def select_device(output, serial=None):
    devices = {}
    for line in output.splitlines():
        fields = line.split()
        if len(fields) >= 2 and not line.startswith(("List ", "*")):
            devices[fields[0]] = fields[1]
    if serial:
        state = devices.get(serial)
        if state != "device":
            raise RuntimeError(f"Teléfono {serial}: {state or 'no detectado'}. Revisa USB y acepta la depuración en Android.")
        return serial
    ready = [identifier for identifier, state in devices.items() if state == "device"]
    if len(ready) > 1:
        raise RuntimeError("Hay varios dispositivos. Selecciona uno con --serial IDENTIFICADOR.")
    if not ready:
        raise RuntimeError("No hay Android autorizado. Conecta un cable de datos, activa depuración USB y acepta la autorización en el teléfono.")
    return ready[0]


def run_command(command):
    result = subprocess.run(command, text=True, capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Falló el comando externo.")
    return result.stdout


def environment_python():
    environment = AGENT / ".venv"
    python = environment / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not python.is_file():
        print("Preparando entorno Python del agente…", flush=True)
        venv.EnvBuilder(with_pip=True).create(environment)
    requirements = AGENT / "requirements.txt"
    fingerprint = hashlib.sha256(requirements.read_bytes()).hexdigest()
    marker = environment / ".requirements.sha256"
    result = subprocess.run([str(python), "-c", "import psutil, websockets"], capture_output=True)
    if result.returncode or not marker.is_file() or marker.read_text() != fingerprint:
        print("Instalando dependencias (requiere internet la primera vez)…", flush=True)
        subprocess.run([str(python), "-m", "pip", "install", "--disable-pip-version-check", "-r", str(requirements)], check=True)
        marker.write_text(fingerprint)
    return python


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--check", action="store_true", help="Diagnosticar Python y USB sin instalar ni arrancar el agente")
    modes.add_argument("--repair-usb", action="store_true", help="Restaurar el reenvío USB sin reiniciar el agente ni la sesión")
    parser.add_argument("--adb", help="Ruta al ejecutable adb o adb.exe")
    parser.add_argument("--serial", help="Dispositivo Android si hay varios conectados")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--token", help="Token opcional; por defecto se genera uno temporal")
    args = parser.parse_args()
    if sys.version_info < (3, 11):
        parser.error("Se necesita Python 3.11 o posterior.")
    if not 1 <= args.port <= 65535:
        parser.error("El puerto debe estar entre 1 y 65535.")
    if args.token is not None and not args.token.strip():
        parser.error("El token no puede estar vacío.")
    try:
        print(f"Python {sys.version.split()[0]} | {sys.platform}", flush=True)
        adb = find_adb(args.adb)
        print(f"ADB: {adb}", flush=True)
        serial = select_device(run_command([adb, "devices"]), args.serial)
        print(f"Android autorizado: {serial}", flush=True)
        if args.check:
            print("Diagnóstico USB correcto. El agente y sus dependencias se prepararán al iniciar.")
            return 0
        run_command([adb, "-s", serial, "reverse", f"tcp:{args.port}", f"tcp:{args.port}"])
        if args.repair_usb:
            print("USB restaurado. Conserva el agente abierto; la app se reconectará automáticamente.")
            return 0
        python = environment_python()
        token = args.token or secrets.token_urlsafe(12)
        print(f"\nAbre PC Monitor en Android:\n  URL: ws://127.0.0.1:{args.port}\n  Token: {token}\nPulsa Conectar. Mantén esta ventana abierta.\n", flush=True)
        # El token viaja por el entorno para que no aparezca en la lista de procesos.
        environment = dict(os.environ, PCMONITOR_TOKEN=token, PYTHONUNBUFFERED="1")
        return subprocess.call([str(python), str(AGENT / "server.py"), "--port", str(args.port)], env=environment, cwd=AGENT)
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nPC Monitor detenido.")
