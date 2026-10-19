import unittest
from types import SimpleNamespace
from unittest.mock import patch

from pcmonitor.metrics import bytes_per_second, collect_snapshot, group_processes, normalize_process_name


class MetricsHelpersTest(unittest.TestCase):
    def test_windows_disk_uses_system_drive_instead_of_current_drive(self):
        with patch("pcmonitor.metrics.platform.system", return_value="Windows"), \
             patch.dict("os.environ", {"SystemDrive": "D:"}), \
             patch("pcmonitor.metrics._process_rows", return_value=[]), \
             patch("pcmonitor.metrics.psutil") as sensors:
            sensors.cpu_percent.return_value = [0]
            sensors.virtual_memory.return_value = SimpleNamespace(used=0, total=100)
            sensors.swap_memory.return_value = SimpleNamespace(used=0)
            sensors.disk_io_counters.return_value = None
            sensors.net_io_counters.return_value = None
            sensors.sensors_battery.return_value = None
            sensors.sensors_temperatures.return_value = {}
            sensors.disk_usage.return_value = SimpleNamespace(used=40, total=100)
            snapshot = collect_snapshot()
        sensors.disk_usage.assert_called_once_with("D:\\")
        self.assertEqual(snapshot["disk"]["total"], 100)

    def test_rate_uses_elapsed_time_and_never_goes_negative(self):
        self.assertEqual(bytes_per_second(120, 20, 2), 50)
        self.assertEqual(bytes_per_second(20, 120, 2), 0)
        self.assertIsNone(bytes_per_second(None, 20, 2))

    def test_process_name_normalization(self):
        self.assertEqual(normalize_process_name("Chrome Helper (Renderer).exe"), "Chrome")
        self.assertEqual(normalize_process_name(None), "?")
        self.assertEqual(normalize_process_name("My Helper Tools.exe"), "My Helper Tools")

    def test_macos_helpers_use_outer_application_bundle(self):
        result = group_processes([
            {"name": "Google Chrome", "mem": 10, "pid": 1,
             "exe": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"},
            {"name": "Google Chrome (Aperitif Renderer)", "mem": 20, "pid": 2,
             "exe": "/Applications/Google Chrome.app/Contents/Helpers/Renderer.app/Contents/MacOS/Renderer"},
        ])
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["app"], "Google Chrome")
        self.assertEqual(result[0]["count"], 2)
        self.assertEqual(result[0]["mem"], 30)

    def test_grouping_keeps_pids_and_paths(self):
        result = group_processes(
            [
                {"name": "worker.exe", "cpu": 2, "mem": 10, "pid": 7, "exe": "C:\\worker.exe"},
                {"name": "worker.exe", "cpu": 3, "mem": 20, "pid": 8, "exe": "C:\\worker.exe"},
                {"name": "other", "cpu": 1, "mem": 5, "pid": 9, "exe": "/usr/bin/other"},
            ]
        )
        self.assertEqual(result[0]["app"], "worker")
        self.assertEqual(result[0]["pids"], [7, 8])
        self.assertEqual([(member["pid"], member["exe"]) for member in result[0]["members"]],
                         [(7, "C:\\worker.exe"), (8, "C:\\worker.exe")])
        self.assertEqual(result[0]["mem"], 30)


if __name__ == "__main__":
    unittest.main()
