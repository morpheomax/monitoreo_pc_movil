import time
import unittest
from unittest.mock import Mock, patch

import psutil

from actions.processes import ActionError, ProcessActions, ProcessPolicy
from history.store import SessionStore
from process_fixture import start_worker


def policy(system="Darwin"):
    result = ProcessPolicy.__new__(ProcessPolicy)
    result.owner = "owner"
    result.protected_pids = {0, 1, 4, 999}
    result.system = system
    return result


def identity():
    return {"pid": 123, "name": "worker", "exe": "/Applications/Worker.app/worker",
            "create_time": 100.0, "username": "owner"}


class PolicyTest(unittest.TestCase):
    def test_protected_names_paths_owner_and_unknown_identity(self):
        info = identity()
        self.assertIsNone(policy().reason(info))
        for changes in [{"pid": 999}, {"name": "WindowServer"}, {"name": "adb"},
                        {"exe": "/System/worker"}, {"exe": None}, {"create_time": None},
                        {"create_time": float("nan")}, {"username": "root"}]:
            with self.subTest(changes=changes):
                self.assertIsNotNone(policy().reason({**info, **changes}))
        for changes in [{"name": "LSASS.EXE"}, {"name": "explorer.exe"},
                        {"exe": r"C:\Windows\System32\hidden.exe"}]:
            self.assertIsNotNone(policy("Windows").reason({**info, **changes}))
        self.assertIsNone(policy("Windows").reason({**info, "exe": r"C:\Users\owner\App.exe"}))

    def test_pid_reuse_and_changed_executable_are_rejected(self):
        process = Mock()
        process.name.return_value = "worker"
        process.username.return_value = "owner"
        process.exe.return_value = identity()["exe"]
        process.create_time.return_value = 101.0
        with patch("actions.processes.psutil.Process", return_value=process):
            with self.assertRaisesRegex(ActionError, "cambió"):
                policy().validate(identity())
            process.create_time.return_value = 100.0
            process.exe.return_value = "/Applications/Another.app/exe"
            with self.assertRaisesRegex(ActionError, "cambió"):
                policy().validate(identity())
        process.terminate.assert_not_called()
        process.kill.assert_not_called()

    def test_nonexistent_and_permission_denied_are_clear(self):
        for error in [psutil.NoSuchProcess(123), psutil.AccessDenied(123)]:
            with patch("actions.processes.psutil.Process", side_effect=error):
                with self.assertRaises(ActionError):
                    policy().validate(identity())


class ActionsTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.process = Mock()
        self.process.is_running.return_value = False
        self.policy = Mock()
        self.policy.validate.return_value = (self.process, identity())
        self.audit = Mock()
        self.actions = ProcessActions("secret", self.policy, self.audit)

    async def test_bad_token_and_missing_confirmation_never_signal(self):
        with self.assertRaises(ActionError):
            self.actions.prepare("wrong", identity())
        self.policy.validate.assert_not_called()
        prepared = self.actions.prepare("secret", identity())
        for token, confirmed, force in [("wrong", True, False), ("secret", False, False), ("secret", True, "yes")]:
            with self.assertRaises(ActionError):
                await self.actions.terminate(token, prepared["ticket"], confirmed, force)
        self.process.terminate.assert_not_called()
        self.process.kill.assert_not_called()

    async def test_ticket_is_connection_local_expiring_and_single_use(self):
        ticket = self.actions.prepare("secret", identity())["ticket"]
        other = ProcessActions("secret", self.policy, self.audit)
        with self.assertRaises(ActionError):
            await other.terminate("secret", ticket, True, False)
        result = await self.actions.terminate("secret", ticket, True, False)
        self.assertEqual(result["status"], "terminated")
        self.process.terminate.assert_called_once()
        with self.assertRaises(ActionError):
            await self.actions.terminate("secret", ticket, True, False)
        ticket = self.actions.prepare("secret", identity())["ticket"]
        with patch("actions.processes.time.monotonic", return_value=time.monotonic() + 31):
            with self.assertRaises(ActionError):
                await self.actions.terminate("secret", ticket, True, False)

    async def test_revalidates_after_confirmation_and_audits_rejection(self):
        ticket = self.actions.prepare("secret", identity())["ticket"]
        self.policy.validate.side_effect = ActionError("PID cambió")
        with self.assertRaises(ActionError):
            await self.actions.terminate("secret", ticket, True, False)
        self.process.terminate.assert_not_called()
        self.assertEqual(self.audit.call_args.args[2], "rejected")

    async def test_audit_failure_prevents_signal(self):
        ticket = self.actions.prepare("secret", identity())["ticket"]
        self.audit.side_effect = OSError("disk full")
        with self.assertRaises(OSError):
            await self.actions.terminate("secret", ticket, True, False)
        self.process.terminate.assert_not_called()

    async def test_force_is_explicit_and_rate_limited(self):
        ticket = self.actions.prepare("secret", identity())["ticket"]
        await self.actions.terminate("secret", ticket, True, True)
        self.process.kill.assert_called_once()
        self.process.terminate.assert_not_called()
        ticket = self.actions.prepare("secret", identity())["ticket"]
        with self.assertRaisesRegex(ActionError, "segundo"):
            await self.actions.terminate("secret", ticket, True, False)

    async def test_access_denied_and_still_running_do_not_escalate(self):
        ticket = self.actions.prepare("secret", identity())["ticket"]
        self.process.terminate.side_effect = psutil.AccessDenied(123)
        with self.assertRaises(ActionError):
            await self.actions.terminate("secret", ticket, True, False)
        self.actions.last_action = float("-inf")
        self.process.terminate.side_effect = None
        self.process.is_running.return_value = True
        self.process.status.return_value = psutil.STATUS_RUNNING
        ticket = self.actions.prepare("secret", identity())["ticket"]
        with patch("actions.processes.asyncio.sleep", new_callable=unittest.mock.AsyncMock):
            result = await self.actions.terminate("secret", ticket, True, False)
        self.assertEqual(result["status"], "still_running")
        self.process.kill.assert_not_called()

    async def test_real_disposable_child_and_session_audit(self):
        child = await start_worker()
        store = SessionStore()
        session = store.start()
        actions = ProcessActions("secret", ProcessPolicy(), store.record_action)
        try:
            info = {"pid": child.pid, "exe": child.exe(), "create_time": child.create_time()}
            ticket = actions.prepare("secret", info)["ticket"]
            result = await actions.terminate("secret", ticket, True, False)
            self.assertEqual(result["status"], "terminated")
            child.wait(timeout=3)
            rows = store.db.execute("SELECT * FROM process_actions").fetchall()
            self.assertEqual([row["result"] for row in rows], ["requested", "signal_sent", "terminated"])
            self.assertTrue(all(row["session_id"] == session["id"] for row in rows))
            self.assertTrue(all(row["pid"] == child.pid for row in rows))
        finally:
            if child.is_running():
                child.kill()
            child.wait(timeout=3)
            store.close()
