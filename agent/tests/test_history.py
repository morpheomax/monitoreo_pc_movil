import csv
from pathlib import Path
import tempfile
import unittest

from history.store import SessionStore


def snapshot(ts, cpu=20, mem=100, groups=None):
    return {"v": 1, "type": "metrics", "ts": ts, "_counters": {"ts": ts},
            "cpu": {"total": cpu}, "mem": {"used": mem, "swap_used": 0},
            "disk": {"read_bps": None, "write_bps": 10},
            "net": {"down_bps": 20, "up_bps": 5},
            "processes": groups if groups is not None else [{"app": "browser", "cpu": 10, "mem": 60}]}


class HistoryTest(unittest.TestCase):
    def setUp(self):
        self.store = SessionStore()
        self.addCleanup(self.store.close)

    def test_report_handles_missing_values_peaks_and_absent_process_groups(self):
        self.store.start(now=100)
        self.store.record(snapshot(101, cpu=None, mem=100))
        self.store.record(snapshot(102, cpu=40, mem=200), processes_sampled=False)
        self.store.record(snapshot(103, cpu=20, mem=150, groups=[]))
        report = self.store.stop(now=104)
        self.assertEqual(report["duration_s"], 4)
        self.assertEqual(report["sample_count"], 3)
        self.assertEqual(report["cpu"], {"avg": 30, "peak": 40, "peak_ts": 102})
        self.assertEqual(report["mem"]["avg_used"], 150)
        self.assertEqual(report["top_apps"][0]["avg_mem"], 30)
        self.assertIsNone(report["thermal"]["throttled_s"])
        self.assertEqual(self.store.reports()[0], report)

    def test_empty_session_and_lifecycle_validation(self):
        with self.assertRaises(ValueError):
            self.store.stop()
        self.store.start(now=100)
        with self.assertRaises(ValueError):
            self.store.start(now=101)
        report = self.store.stop(now=102)
        self.assertEqual(report["sample_count"], 0)
        self.assertIsNone(report["cpu"]["avg"])
        self.assertEqual(report["top_apps"], [])

    def test_retention_aggregates_once_preserving_report_and_counts(self):
        self.store.start(now=100)
        self.store.record(snapshot(101, cpu=20))
        self.store.record(snapshot(102, cpu=40))
        report = self.store.stop(now=103)
        # stop ya aplica retención porque los timestamps son antiguos.
        self.store.prune(now=1000000)
        self.store.prune(now=1000001)
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM samples").fetchone()[0], 0)
        row = self.store.db.execute("SELECT sample_count, cpu_avg, cpu_peak FROM minute_samples").fetchone()
        self.assertEqual(tuple(row), (2, 30, 40))
        self.assertEqual(self.store.get_report(report["session_id"]), report)
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM process_samples").fetchone()[0], 0)

    def test_recovery_ends_at_last_saved_sample_and_export_stays_local(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sessions.sqlite3"
            store = SessionStore(path)
            identifier = store.start(now=100)["id"]
            store.record(snapshot(105, groups=[{"app": "=formula", "cpu": 1, "mem": 10}]))
            store.close()
            recovered = SessionStore(path)
            try:
                self.assertIsNone(recovered.active)
                report = recovered.get_report(identifier)
                self.assertTrue(report["interrupted"])
                self.assertEqual(report["duration_s"], 5)
                exported = Path(recovered.export(identifier))
                self.assertTrue(exported.is_relative_to(Path(directory)))
                self.assertTrue((exported / "minutes.csv").is_file())
                with (exported / "top_apps.csv").open(encoding="utf-8-sig") as file:
                    self.assertEqual(list(csv.reader(file))[1][0], "'=formula")
                with self.assertRaises(ValueError):
                    recovered.export("../../outside")
            finally:
                recovered.close()
