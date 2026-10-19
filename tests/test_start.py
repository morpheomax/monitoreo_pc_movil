import unittest
from unittest.mock import patch

from start import find_adb, main, select_device


class UsbStartupTest(unittest.TestCase):
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
