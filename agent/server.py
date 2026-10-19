#!/usr/bin/env python3
"""Agente local: muestreador compartido, WebSocket v1 y sesiones SQLite."""

import argparse
import asyncio
import json
import math
import logging
import os
import platform
import secrets
import sqlite3

import psutil
import websockets

from actions.processes import ProcessActions, ProcessPolicy
from history.store import SessionStore, default_data_dir
from pcmonitor.metrics import collect_snapshot
from pcmonitor.instance_lock import AgentLock


CAPABILITIES = ["metrics", "processes", "sessions", "history", "session_export", "process_actions"]


def welcome_message():
    return {"v": 1, "type": "welcome", "host": platform.node(),
            "os": platform.system().lower(), "os_version": platform.release(),
            "cpu_model": platform.processor() or None, "cores": psutil.cpu_count(),
            "ram_total": psutil.virtual_memory().total, "capabilities": CAPABILITIES}


class MonitorServer:
    def __init__(self, token, interval=1.0, store=None):
        self.token = token
        self.interval = interval
        self.store = store or SessionStore()
        self.clients = set()
        self._sampler = None
        self._condition = asyncio.Condition()
        self._latest = None
        self._sequence = 0
        self.policy = ProcessPolicy()
        self._actions = {}
        self._refresh_processes = False

    @staticmethod
    async def send(websocket, message_type, **fields):
        await websocket.send(json.dumps({"v": 1, "type": message_type, **fields}))

    def ensure_sampling(self):
        if self._sampler is None or self._sampler.done():
            self._sampler = asyncio.create_task(self.sample_loop())
            self._sampler.add_done_callback(self._sampling_done)

    @staticmethod
    def _sampling_done(task):
        if not task.cancelled() and task.exception():
            error = task.exception()
            logging.error("Fallo de captura", exc_info=(type(error), error, error.__traceback__))

    async def sample_loop(self):
        previous = {}
        next_processes = 0
        loop = asyncio.get_running_loop()
        try:
            while self.clients or self.store.active:
                started = loop.time()
                processes_due = started >= next_processes or self._refresh_processes
                self._refresh_processes = False
                snapshot = collect_snapshot(previous, include_processes=processes_due)
                previous = snapshot
                if processes_due:
                    next_processes = started + 3
                self.store.record(snapshot, processes_due)
                async with self._condition:
                    self._latest = (snapshot, processes_due)
                    self._sequence += 1
                    self._condition.notify_all()
                await asyncio.sleep(max(0, self.interval - (loop.time() - started)))
        except Exception:
            # Un fallo de captura no debe dejar el dashboard conectado con datos congelados.
            for client in tuple(self.clients):
                await client.close(1011, "Error de captura; revisar agente")
            raise
        finally:
            self._latest = None

    async def handler(self, websocket):
        tasks = []
        try:
            hello = json.loads(await asyncio.wait_for(websocket.recv(), timeout=10))
            if (not isinstance(hello, dict) or hello.get("v") != 1 or hello.get("type") != "hello"
                    or not isinstance(hello.get("token"), str)
                    or not secrets.compare_digest(hello["token"].encode(), self.token.encode())):
                await self.send(websocket, "error", code="unauthorized", message="Token inválido. Usa el token de la ventana del computador.")
                return
            await websocket.send(json.dumps(welcome_message()))
            await self.send(websocket, "session_state", active=self.store.active)
            self.clients.add(websocket)
            self.ensure_sampling()
            tasks = [asyncio.create_task(self.stream(websocket)), asyncio.create_task(self.receive(websocket))]
            done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            for task in done:
                task.result()
        except (asyncio.TimeoutError, json.JSONDecodeError, UnicodeDecodeError, websockets.ConnectionClosed):
            return
        finally:
            self.clients.discard(websocket)
            self._actions.pop(websocket, None)
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)

    async def stream(self, websocket):
        sequence = -1
        while True:
            async with self._condition:
                await self._condition.wait_for(lambda: self._latest is not None and sequence != self._sequence)
                snapshot, processes_due = self._latest
                first = sequence == -1
                sequence = self._sequence
            metrics = {key: value for key, value in snapshot.items() if key not in {"processes", "host", "_counters"}}
            await websocket.send(json.dumps(metrics))
            if processes_due or first:
                await self.send(websocket, "processes", ts=snapshot["ts"], groups=snapshot["processes"])

    async def broadcast_state(self):
        await asyncio.gather(*(self.send(client, "session_state", active=self.store.active)
                               for client in tuple(self.clients)), return_exceptions=True)

    async def receive(self, websocket):
        async for raw in websocket:
            await self.dispatch(websocket, raw)

    async def dispatch(self, websocket, raw):
        identifier = None
        try:
            message = json.loads(raw)
            if not isinstance(message, dict) or message.get("v") != 1:
                raise ValueError("Mensaje o versión de protocolo inválidos.")
            identifier = message.get("id")
            if not isinstance(identifier, str) or not 1 <= len(identifier) <= 80:
                raise ValueError("La petición requiere un identificador válido.")
            command = message.get("type")
            if command in {"process_prepare", "process_terminate"}:
                if websocket not in self.clients:
                    raise ValueError("La conexión no está autenticada.")
                if websocket not in self._actions:
                    self._actions[websocket] = ProcessActions(self.token, self.policy, self.store.record_action)
                actions = self._actions[websocket]
                if command == "process_prepare":
                    result = actions.prepare(message.get("token"), message.get("process"))
                else:
                    result = await actions.terminate(message.get("token"), message.get("ticket"),
                                                     message.get("confirmed"), message.get("force", False))
                    self._refresh_processes = True
                await self.send(websocket, "ack", id=identifier, ok=True, **result)
            elif command == "session_start":
                self.store.start()
                self.ensure_sampling()
                await self.broadcast_state()
                await self.send(websocket, "ack", id=identifier, ok=True)
            elif command == "session_stop":
                report = self.store.stop()
                await self.broadcast_state()
                await self.send(websocket, "session_report", id=identifier, report=report)
            elif command == "session_history":
                await self.send(websocket, "session_history", id=identifier, reports=self.store.reports())
            elif command == "session_export":
                session_id = message.get("session_id")
                if not isinstance(session_id, str):
                    raise ValueError("Falta el identificador de sesión.")
                directory = self.store.export(session_id)
                await self.send(websocket, "ack", id=identifier, ok=True, export_path=directory)
            else:
                raise ValueError("Acción no disponible en esta versión del agente.")
        except (ValueError, TypeError, UnicodeDecodeError) as error:
            await self.send(websocket, "ack", id=identifier, ok=False, message=str(error))
        except (OSError, sqlite3.Error):
            await self.send(websocket, "ack", id=identifier, ok=False, message="No se pudo guardar el historial. Revisa espacio y permisos en el computador.")

    async def close(self):
        if self._sampler:
            self._sampler.cancel()
            await asyncio.gather(self._sampler, return_exceptions=True)
        # La sesión queda identificada como interrumpida al volver a iniciar el agente.
        self.store.close()


async def run(host, port, token, interval, data_dir=None):
    directory = data_dir or default_data_dir()
    with AgentLock(directory / ".agent.lock"):
        store = SessionStore(directory / "sessions.sqlite3")
        server = MonitorServer(token, interval, store)
        try:
            async with websockets.serve(server.handler, host, port, max_size=65536, max_queue=16):
                print(f"PC Monitor escuchando en ws://{host}:{port}")
                print(f"Historial y exportaciones: {directory}")
                print("Pulsa Ctrl+C para detenerlo. Si hay una sesión activa se marcará interrumpida al reiniciar.")
                await asyncio.Future()
        finally:
            await server.close()

def main():
    from pathlib import Path
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--token", default=os.environ.get("PCMONITOR_TOKEN"))
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument("--data-dir", type=Path, help="Carpeta local para historial y CSV")
    args = parser.parse_args()
    if not args.token or not args.token.strip():
        parser.error("Indica --token o PCMONITOR_TOKEN.")
    if not math.isfinite(args.interval) or args.interval < 0.5:
        parser.error("El intervalo debe ser finito y al menos 0.5 segundos.")
    if not 1 <= args.port <= 65535:
        parser.error("El puerto debe estar entre 1 y 65535.")
    if args.host not in {"127.0.0.1", "::1", "localhost"}:
        parser.error("Este MVP solo admite localhost; Wi-Fi requiere TLS y emparejamiento.")
    try:
        asyncio.run(run(args.host, args.port, args.token, args.interval, args.data_dir))
    except KeyboardInterrupt:
        pass
    except (RuntimeError, OSError, sqlite3.Error) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
