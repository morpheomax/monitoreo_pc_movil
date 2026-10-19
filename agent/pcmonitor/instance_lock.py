"""Bloqueo del historial entre procesos; el SO lo libera incluso tras un cierre abrupto."""

import os


class AgentLock:
    def __init__(self, path):
        self.path = path
        self.file = None

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.file = self.path.open("a+b")
        try:
            if os.name == "nt":
                import msvcrt
                if self.path.stat().st_size == 0:
                    self.file.write(b"0")
                    self.file.flush()
                self.file.seek(0)
                msvcrt.locking(self.file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            self.file.close()
            raise RuntimeError("Ya hay otro agente usando este historial. Cierra su ventana antes de iniciar otro.") from error
        return self

    def __exit__(self, *args):
        # Cerrar el descriptor libera el bloqueo en ambos sistemas.
        self.file.close()
