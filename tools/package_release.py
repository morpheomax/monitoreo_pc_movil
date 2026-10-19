#!/usr/bin/env python3
"""Crear/verificar entregables sin incluir entornos, credenciales ni historial."""

import argparse
import hashlib
import io
from pathlib import Path
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
AGENT_VERSION = "0.3.0"


def app_version():
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+\d+", (ROOT / "app/pubspec.yaml").read_text(), re.M)
    if not match:
        raise ValueError("No se encontró la versión de Android en pubspec.yaml")
    return match[1]


def content(relative):
    data = (ROOT / relative).read_bytes()
    # Los .cmd deben ser iguales al empaquetar en Windows o Mac.
    if relative.endswith(".cmd"):
        data = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
    return data


def package_files(common):
    names = ["start.py", "Start Windows.cmd", "Repair USB Windows.cmd", "tests/test_start.py",
             "agent/server.py", "agent/requirements.txt"]
    for directory in ["actions", "history", "pcmonitor", "tests"]:
        names.extend(path.relative_to(ROOT).as_posix() for path in sorted((ROOT / "agent" / directory).glob("*.py")))
    files = {"PCMonitor/" + name: content(name) for name in names}
    files["PCMonitor/LEEME-WINDOWS.md"] = content("docs/10-ejecutar-windows.md")
    if common:
        files["PCMonitor/Start Mac.command"] = content("Start Mac.command")
        files["PCMonitor/LEEME-MAC.md"] = content("docs/12-ejecutar-macos.md")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        readme = readme[:readme.index("## Estado y desarrollo")]
        start = readme.index("## Archivos que necesitas")
        end = readme.index("## 1. Preparar el teléfono")
        readme = (readme[:start] + "## Archivos de esta entrega\n\n"
                  f"Agente {AGENT_VERSION}. El APK `pcmonitor-android-{app_version()}-arm64.apk` se entrega por separado.\n"
                  "Guías específicas: [Windows](LEEME-WINDOWS.md) y [Mac](LEEME-MAC.md).\n"
                  "Prepara Python 3.11+ y Platform-Tools para tu sistema; no copies entornos entre equipos.\n\n"
                  + readme[end:])
        readme = readme.replace("](docs/10-ejecutar-windows.md)", "](LEEME-WINDOWS.md)")
        files["PCMonitor/LEEME.md"] = readme.encode("utf-8")
    return files


def archive(files):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name)  # Fecha fija: empaquetado reproducible.
            info.create_system = 3
            info.external_attr = (0o100755 if name.endswith(".command") else 0o100644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            bundle.writestr(info, data)
    return output.getvalue()


def verify_archive(path, expected):
    with zipfile.ZipFile(path) as bundle:
        if bundle.testzip() is not None or set(bundle.namelist()) != set(expected):
            raise ValueError(f"ZIP incompleto o dañado: {path.name}")
        for name, data in expected.items():
            if bundle.read(name) != data:
                raise ValueError(f"Fuente o guía desactualizada: {path.name}/{name}")
            if name.endswith(".command") and not (bundle.getinfo(name).external_attr >> 16) & 0o111:
                raise ValueError("Falta permiso de ejecución del lanzador Mac")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verificar fuentes/guías, CRC y SHA-256 sin compilar Android")
    parser.add_argument("--apk", type=Path, default=ROOT / "app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk")
    args = parser.parse_args()
    apk = DIST / f"pcmonitor-android-{app_version()}-arm64.apk"
    packages = [(DIST / f"pcmonitor-agent-{AGENT_VERSION}.zip", True),
                (DIST / f"pcmonitor-windows-agent-{AGENT_VERSION}.zip", False)]
    if not args.check:
        if not args.apk.is_file():
            raise ValueError("Compila el APK release o indica --apk RUTA antes de empaquetar")
        DIST.mkdir(exist_ok=True)
        shutil.copyfile(args.apk, apk)
        for path, common in packages:
            path.write_bytes(archive(package_files(common)))
    for path, common in packages:
        verify_archive(path, package_files(common))
    checksums = "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
                        for path in [apk, *(item[0] for item in packages)])
    manifest = DIST / "SHA256SUMS.txt"
    if args.check:
        if manifest.read_text(encoding="utf-8") != checksums:
            raise ValueError("Los SHA-256 no corresponden a los entregables vigentes")
    else:
        manifest.write_text(checksums, encoding="utf-8")
    print(f"Android {app_version()} / agente {AGENT_VERSION}: fuentes, guías, CRC y SHA-256 correctos.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        sys.exit(f"Error: {error}")
