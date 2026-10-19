import unittest
import json
import urllib.error
import urllib.request
from unittest.mock import patch

from start import UsbPairing, find_adb, main, select_device


class UsbStartupTest(unittest.TestCase):
    def test_manual_mode_and_usb_failure_keep_manual_agent_available(self):
        for manual in [False, True]:
            with self.subTest(manual=manual), \
                 patch("sys.argv", ["start.py"] + (["--manual-connection"] if manual else [])), \
                 patch("start.find_adb", return_value="adb"), \
                 patch("start.run_command", side_effect=["phone\tdevice", ""]), \
                 patch("start.environment_python", return_value="python"), \
                 patch("start.UsbPairing") as pairing, \
                 patch("start.subprocess.Popen") as launch, patch("builtins.print"):
                pairing.return_value.launch.side_effect = RuntimeError("Old APK")
                launch.return_value.__enter__.return_value.wait.return_value = 0
                self.assertEqual(main(), 0)
                if manual:
                    pairing.assert_not_called()
                else:
                    pairing.return_value.close.assert_called_once_with("adb", "phone")
                self.assertNotIn("PCMONITOR_TOKEN", " ".join(launch.call_args.args[0]))
                self.assertTrue(launch.call_args.kwargs['env']['PCMONITOR_TOKEN'])

    def test_pairing_requires_nonce_expires_and_is_single_use(self):
        pairing = UsbPairing("test-ephemeral-credential", 8766)
        pairing.thread.start()
        try:
            base = f"http://127.0.0.1:{pairing.port}"
            with self.assertRaises(urllib.error.HTTPError) as invalid:
                urllib.request.urlopen(base + "/pair/wrong", timeout=3)
            self.assertEqual(invalid.exception.code, 410)
            with urllib.request.urlopen(base + pairing.path, timeout=3) as response:
                self.assertEqual(response.headers['Cache-Control'], 'no-store')
                data = json.load(response)
            self.assertEqual(data['v'], 1)
            self.assertEqual(data['token'], "test-ephemeral-credential")
            self.assertEqual(data['url'], "ws://127.0.0.1:8766")
            self.assertEqual(pairing.payload, {})
            with self.assertRaises(urllib.error.HTTPError) as replay:
                urllib.request.urlopen(base + pairing.path, timeout=3)
            self.assertEqual(replay.exception.code, 410)
        finally:
            with patch("start.run_command"):
                pairing.close("adb", "phone")

    def test_expired_pairing_does_not_disclose_credentials(self):
        pairing = UsbPairing("test-expired-credential", 8765, lifetime=-1)
        pairing.thread.start()
        try:
            pairing.thread.join(timeout=2)
            self.assertFalse(pairing.thread.is_alive())
            self.assertEqual(pairing.payload, {})
            with self.assertRaises(urllib.error.URLError):
                urllib.request.urlopen(f"http://127.0.0.1:{pairing.port}{pairing.path}", timeout=3)
        finally:
            with patch("start.run_command"):
                pairing.close("adb", "phone")

    def test_activity_arguments_never_contain_agent_token(self):
        pairing = UsbPairing("test-not-in-arguments", 8765)
        try:
            with patch("start.run_command", return_value="") as command:
                pairing.launch("adb", "phone")
            activity = command.call_args.args[0]
            self.assertNotIn("test-not-in-arguments", " ".join(activity))
            self.assertIn("com.innextsolutions.pcmonitor/.MainActivity", activity)
            self.assertIn(f"http://127.0.0.1:{pairing.port}{pairing.path}", activity)
        finally:
            with patch("start.run_command"):
                pairing.close("adb", "phone")

    def test_repair_usb_preserves_agent_without_preparing_or_starting_another(self):
        with patch("sys.argv", ["start.py", "--repair-usb"]), \
             patch("start.find_adb", return_value="adb"), \
             patch("start.run_command", side_effect=["phone\tdevice", ""]) as command, \
             patch("start.environment_python") as prepare, patch("start.subprocess.call") as launch, \
             patch("builtins.print"):
            self.assertEqual(main(), 0)
        prepare.assert_not_called()
        launch.assert_not_called()
        self.assertEqual(command.call_args.args[0], ["adb", "-s", "phone", "reverse", "tcp:8765", "tcp:8765"])

    def test_selects_authorized_device_among_unauthorized_devices(self):
        output = "List of devices attached\nphone1\tunauthorized\nphone2\tdevice\n"
        self.assertEqual(select_device(output), "phone2")

    def test_requires_explicit_selection_when_multiple_devices_are_ready(self):
        output = "List of devices attached\nphone1\tdevice\nphone2\tdevice\n"
        with self.assertRaisesRegex(RuntimeError, "--serial"):
            select_device(output)
        self.assertEqual(select_device(output, "phone2"), "phone2")

    def test_missing_offline_and_unauthorized_devices_stop_startup(self):
        for output in ["List of devices attached\n", "phone\toffline", "phone\tunauthorized"]:
            with self.subTest(output=output), self.assertRaises(RuntimeError):
                select_device(output)
        with self.assertRaises(RuntimeError):
            select_device("other\tdevice", "missing")

    def test_finds_sdk_without_requiring_path_configuration(self):
        with patch("start.shutil.which", return_value=None), patch.dict(
            "start.os.environ", {"ANDROID_HOME": "/test-sdk"}
        ), patch("start.Path.is_file", return_value=True):
            self.assertIn("platform-tools", find_adb())


if __name__ == "__main__":
    unittest.main()
