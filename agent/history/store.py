"""SQLite local: una sesión por equipo; informes conservados tras la retención."""

import csv
import json
import os
from pathlib import Path
import platform
import sqlite3
import time
import uuid


SAMPLE_FIELDS = ("cpu", "mem_used", "swap_used", "disk_read_bps", "disk_write_bps", "net_down_bps", "net_up_bps")


def default_data_dir():
    if platform.system() == "Windows":
        return Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData/Local")) / "PCMonitor"
    return Path.home() / "Library/Application Support/PCMonitor"


class SessionStore:
    def __init__(self, path=":memory:"):
        self.path = Path(path) if str(path) != ":memory:" else None
        if self.path:
            self.path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(str(path))
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.execute("PRAGMA journal_mode=WAL")
        columns = ", ".join(f"{field} REAL" for field in SAMPLE_FIELDS)
        self.db.executescript(f"""
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY, started_at REAL NOT NULL, ended_at REAL,
                host TEXT NOT NULL, os TEXT NOT NULL, report TEXT
            );
            CREATE TABLE IF NOT EXISTS process_actions (
                id INTEGER PRIMARY KEY, session_id TEXT REFERENCES sessions(id),
                ts REAL NOT NULL, client TEXT NOT NULL, action TEXT NOT NULL,
                pid INTEGER NOT NULL, exe TEXT, create_time REAL,
                result TEXT NOT NULL, message TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS samples (
                session_id TEXT NOT NULL REFERENCES sessions(id), ts REAL NOT NULL,
                {columns}, processes_sampled INTEGER NOT NULL, payload TEXT NOT NULL,
                PRIMARY KEY (session_id, ts)
            );
            CREATE TABLE IF NOT EXISTS process_samples (
                session_id TEXT NOT NULL REFERENCES sessions(id), ts REAL NOT NULL,
                app TEXT NOT NULL, cpu REAL, mem REAL,
                PRIMARY KEY (session_id, ts, app)
            );
            CREATE TABLE IF NOT EXISTS minute_samples (
                session_id TEXT NOT NULL REFERENCES sessions(id), minute INTEGER NOT NULL,
                sample_count INTEGER NOT NULL, cpu_avg REAL, cpu_peak REAL,
                mem_avg REAL, mem_peak REAL, swap_avg REAL,
                disk_read_avg REAL, disk_write_avg REAL, net_down_avg REAL, net_up_avg REAL,
                PRIMARY KEY (session_id, minute)
            );
        """)
        self.active = None
        # Tras reiniciar no se inventa tiempo medido: el informe llega a la última muestra.
        for row in self.db.execute("SELECT id, started_at FROM sessions WHERE ended_at IS NULL").fetchall():
            last = self.db.execute("SELECT MAX(ts) FROM samples WHERE session_id=?", (row["id"],)).fetchone()[0]
            self._finish(row["id"], last or row["started_at"], interrupted=True)
        self.prune()

    def start(self, now=None):
        if self.active:
            raise ValueError("Ya hay una sesión activa en este equipo.")
        active = {"id": str(uuid.uuid4()), "started_at": time.time() if now is None else now}
        with self.db:
            self.db.execute("INSERT INTO sessions(id, started_at, host, os) VALUES (?, ?, ?, ?)",
                            (active["id"], active["started_at"], platform.node(), platform.system().lower()))
        self.active = active
        return self.active

    def record(self, snapshot, processes_sampled=True):
        if not self.active:
            return
        values = [snapshot["cpu"]["total"], snapshot["mem"]["used"], snapshot["mem"]["swap_used"],
                  snapshot["disk"]["read_bps"], snapshot["disk"]["write_bps"],
                  snapshot["net"]["down_bps"], snapshot["net"]["up_bps"]]
        # ts de precisión real evita colisiones si el intervalo del agente es <1 segundo.
        ts = snapshot.get("_counters", {}).get("ts", snapshot["ts"])
        identifier = self.active["id"]
        with self.db:
            payload = {key: value for key, value in snapshot.items() if key not in {"processes", "host", "_counters"}}
            self.db.execute("INSERT OR REPLACE INTO samples VALUES (" + ",".join("?" for _ in range(11)) + ")",
                            [identifier, ts, *values, int(processes_sampled), json.dumps(payload)])
            if processes_sampled:
                self.db.executemany("INSERT OR REPLACE INTO process_samples VALUES (?, ?, ?, ?, ?)",
                                    [(identifier, ts, group["app"], group["cpu"], group["mem"]) for group in snapshot["processes"]])

    def record_action(self, info, action, result, message):
        with self.db:
            self.db.execute("""INSERT INTO process_actions
                (session_id, ts, client, action, pid, exe, create_time, result, message)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (self.active["id"] if self.active else None, time.time(), "android-usb",
                 action, info["pid"], info.get("exe"), info.get("create_time"), result, message))

    def stop(self, now=None):
        if not self.active:
            raise ValueError("No hay una sesión activa.")
        report = self._finish(self.active["id"], time.time() if now is None else now)
        self.active = None
        self.prune()
        return report

    def _finish(self, identifier, ended_at, interrupted=False):
        session = self.db.execute("SELECT * FROM sessions WHERE id=?", (identifier,)).fetchone()
        stats = self.db.execute("""SELECT COUNT(*) AS samples, AVG(cpu) AS cpu_avg, MAX(cpu) AS cpu_peak,
            AVG(mem_used) AS mem_avg, MAX(mem_used) AS mem_peak, SUM(processes_sampled) AS frames
            FROM samples WHERE session_id=?""", (identifier,)).fetchone()
        def peak_time(field):
            row = self.db.execute(f"SELECT ts FROM samples WHERE session_id=? AND {field} IS NOT NULL ORDER BY {field} DESC, ts LIMIT 1", (identifier,)).fetchone()
            return row[0] if row else None
        top = self.db.execute("""SELECT app, SUM(mem)/? AS avg_mem, SUM(cpu)/? AS avg_cpu
            FROM process_samples WHERE session_id=? GROUP BY app ORDER BY avg_mem DESC LIMIT 10""",
                              (stats["frames"] or 1, stats["frames"] or 1, identifier)).fetchall()
        report = {"session_id": identifier, "host": session["host"], "os": session["os"],
                  "started_at": session["started_at"], "ended_at": ended_at,
                  "duration_s": max(0, ended_at - session["started_at"]), "sample_count": stats["samples"],
                  "interrupted": interrupted,
                  "cpu": {"avg": stats["cpu_avg"], "peak": stats["cpu_peak"], "peak_ts": peak_time("cpu")},
                  "mem": {"avg_used": stats["mem_avg"], "peak_used": stats["mem_peak"], "peak_ts": peak_time("mem_used")},
                  "top_apps": [dict(row) for row in top], "top_apps_scope": "top_20_sampled_groups",
                  "thermal": {"throttled_s": None, "reason": "throttling_sensor_unavailable"},
                  "freed": {"mem_bytes": None, "reason": "not_measured"}}
        with self.db:
            self.db.execute("UPDATE sessions SET ended_at=?, report=? WHERE id=?", (ended_at, json.dumps(report), identifier))
        return report

    def reports(self, limit=30):
        return [json.loads(row[0]) for row in self.db.execute(
            "SELECT report FROM sessions WHERE report IS NOT NULL ORDER BY started_at DESC LIMIT ?", (limit,))]

    def get_report(self, identifier):
        row = self.db.execute("SELECT report FROM sessions WHERE id=? AND report IS NOT NULL", (identifier,)).fetchone()
        if not row:
            raise ValueError("Informe no encontrado en este equipo.")
        return json.loads(row[0])

    def export(self, identifier):
        report = self.get_report(identifier)
        if not self.path:
            raise ValueError("La exportación requiere una base de datos en disco.")
        directory = self.path.parent / "exports" / report["session_id"]
        directory.mkdir(parents=True, exist_ok=True)
        self._write_csv(directory / "samples.csv", self.db.execute(
            "SELECT ts, " + ", ".join(SAMPLE_FIELDS) + ", payload FROM samples WHERE session_id=? ORDER BY ts", (identifier,)))
        self._write_csv(directory / "minutes.csv", self.db.execute(
            "SELECT * FROM minute_samples WHERE session_id=? ORDER BY minute", (identifier,)))
        # Un nombre de proceso puede empezar con '='; evitar fórmulas al abrir el CSV.
        with (directory / "top_apps.csv").open("w", newline="", encoding="utf-8-sig") as file:
            writer = csv.writer(file)
            writer.writerow(["app", "avg_mem", "avg_cpu"])
            for app in report["top_apps"]:
                name = app["app"]
                if name.startswith(("=", "+", "-", "@", "\t", "\r", "\n")):
                    name = "'" + name
                writer.writerow([name, app["avg_mem"], app["avg_cpu"]])
        (directory / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        return str(directory)

    @staticmethod
    def _write_csv(path, cursor):
        with path.open("w", newline="", encoding="utf-8-sig") as file:
            writer = csv.writer(file)
            writer.writerow([column[0] for column in cursor.description])
            writer.writerows(cursor)

    def prune(self, now=None):
        cutoff = (time.time() if now is None else now) - 7 * 86400
        # Migrar solo minutos completos y sesiones terminadas; el informe ya es permanente.
        cutoff = int(cutoff // 60) * 60
        with self.db:
            self.db.execute("""INSERT OR REPLACE INTO minute_samples
                SELECT session_id, CAST(ts/60 AS INTEGER)*60, COUNT(*), AVG(cpu), MAX(cpu),
                    AVG(mem_used), MAX(mem_used), AVG(swap_used), AVG(disk_read_bps),
                    AVG(disk_write_bps), AVG(net_down_bps), AVG(net_up_bps)
                FROM samples WHERE ts < ? AND session_id IN (SELECT id FROM sessions WHERE ended_at IS NOT NULL)
                GROUP BY session_id, CAST(ts/60 AS INTEGER)""", (cutoff,))
            for table in ("samples", "process_samples"):
                self.db.execute(f"DELETE FROM {table} WHERE ts < ? AND session_id IN (SELECT id FROM sessions WHERE ended_at IS NOT NULL)", (cutoff,))

    def close(self):
        self.db.close()
