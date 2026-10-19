from pathlib import Path
import tempfile
import unittest

from pcmonitor.instance_lock import AgentLock


class InstanceLockTest(unittest.TestCase):
    def test_another_agent_cannot_open_live_history_and_lock_is_reusable(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".agent.lock"
            with AgentLock(path):
                with self.assertRaises(RuntimeError):
                    with AgentLock(path):
                        self.fail("No debe permitir dos agentes sobre el mismo historial")
            with AgentLock(path):
                pass
