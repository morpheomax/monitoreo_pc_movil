import asyncio
import json
import tempfile
import time
from pathlib import Path
import unittest
from unittest.mock import AsyncMock, Mock, patch

import websockets

from history.store import SessionStore
from server import CAPABILITIES, MonitorServer
from test_history import snapshot
from process_fixture import start_worker


class AuthenticationTest(unittest.IsolatedAsyncioTestCase):
    async def test_malformed_or_wrong_credentials_never_start_sampling(self):
        for hello in [None, [], 42, {"v": 1, "type": "hello", "token": "wrong"},
                      {"v": 2, "type": "hello", "token": "secret"},
                      {"v": 1, "type": "hello", "token": "ñ"}]:
            with self.subTest(hello=hello):
                server = MonitorServer("secret")
                server.ensure_sampling = Mock()
                socket = AsyncMock()
                socket.recv.return_value = json.dumps(hello)
                try:
                    await server.handler(socket)
                    self.assertEqual(json.loads(socket.send.call_args.args[0])["code"], "unauthorized")
                    server.ensure_sampling.assert_not_called()
                finally:
                    await server.close()


class ServerIntegrationTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.store = SessionStore(Path(self.directory.name) / "sessions.sqlite3")
        self.server = MonitorServer("secret", interval=0.03, store=self.store)
        self.collector = patch("server.collect_snapshot", side_effect=lambda *args, **kwargs: snapshot(time.time()))
        self.collector.start()
        self.listener = await websockets.serve(self.server.handler, "127.0.0.1", 0)
        self.url = f"ws://127.0.0.1:{self.listener.sockets[0].getsockname()[1]}"

    async def asyncTearDown(self):
        self.listener.close()
        await self.listener.wait_closed()
        await self.server.close()
        self.collector.stop()
        self.directory.cleanup()

    async def until(self, socket, message_type):
        async with asyncio.timeout(3):
            while True:
                message = json.loads(await socket.recv())
                if message["type"] == message_type:
                    return message

    async def connect(self):
        socket = await websockets.connect(self.url)
        await socket.send(json.dumps({"v": 1, "type": "hello", "token": "secret"}))
        welcome = await self.until(socket, "welcome")
        self.assertEqual(welcome["capabilities"], CAPABILITIES)
        return socket

    async def test_sessions_survive_phone_disconnect_and_reconnect(self):
        async with await self.connect() as socket:
            await self.until(socket, "session_state")
            await socket.send(json.dumps({"v": 1, "type": "session_start", "id": "start"}))
            state = await self.until(socket, "session_state")
            session_id = state["active"]["id"]
            await self.until(socket, "ack")
            await asyncio.sleep(.08)
        count = self.store.db.execute("SELECT COUNT(*) FROM samples").fetchone()[0]
        await asyncio.sleep(.12)
        self.assertGreater(self.store.db.execute("SELECT COUNT(*) FROM samples").fetchone()[0], count)
        async with await self.connect() as socket:
            state = await self.until(socket, "session_state")
            self.assertEqual(state["active"]["id"], session_id)
            await socket.send(json.dumps({"v": 1, "type": "session_stop", "id": "stop"}))
            report = (await self.until(socket, "session_report"))["report"]
            self.assertGreater(report["sample_count"], 1)
            await socket.send(json.dumps({"v": 1, "type": "session_export", "id": "export", "session_id": session_id}))
            exported = await self.until(socket, "ack")
            self.assertTrue(Path(exported["export_path"]).joinpath("samples.csv").is_file())

    async def test_process_close_requires_authorization_and_confirmation(self):
        child = await start_worker()
        identity = {"pid": child.pid, "exe": child.exe(), "create_time": child.create_time()}
        try:
            async with await self.connect() as socket:
                for token in ["wrong", "secret"]:
                    await socket.send(json.dumps({"v": 1, "type": "process_prepare", "id": "prepare",
                                                 "token": token, "process": identity}))
                    prepared = await self.until(socket, "ack")
                    self.assertEqual(prepared["ok"], token == "secret", prepared.get("message"))
                await socket.send(json.dumps({"v": 1, "type": "process_terminate", "id": "cancel",
                                             "token": "secret", "ticket": prepared["ticket"], "confirmed": False}))
                self.assertFalse((await self.until(socket, "ack"))["ok"])
                self.assertTrue(child.is_running())
                await socket.send(json.dumps({"v": 1, "type": "process_terminate", "id": "close",
                                             "token": "secret", "ticket": prepared["ticket"], "confirmed": True}))
                result = await self.until(socket, "ack")
                self.assertEqual(result["status"], "terminated")
                child.wait(timeout=3)
        finally:
            if child.is_running():
                child.kill()
            child.wait(timeout=3)

    async def test_multiple_clients_share_sampler_and_unsupported_commands_are_rejected(self):
        async with await self.connect() as first:
            sampler = self.server._sampler
            async with await self.connect() as second:
                self.assertIs(self.server._sampler, sampler)
                await self.until(second, "metrics")
                await first.send(json.dumps({"v": 1, "type": "kill", "id": "forbidden"}))
                ack = await self.until(first, "ack")
                self.assertFalse(ack["ok"])
        await asyncio.sleep(.08)
        self.assertTrue(sampler.done())
