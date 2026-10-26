"""Límites de uso de la investigación asistida (Bloque 7C).

En memoria del proceso: se reinician al reiniciar la API y no se comparten entre procesos
(Docker ejecuta un único proceso de Uvicorn). No son un tope de facturación de ningún proveedor.
"""

import threading
import time
from collections import defaultdict, deque
from contextlib import contextmanager
from enum import StrEnum


class Accion(StrEnum):
    busqueda = "busqueda"  # búsqueda en Crossref (/works)
    consulta_doi = "consulta_doi"  # una obra por DOI en Crossref (/works/{doi})
    redaccion = "redaccion"  # llamada a Gemini sin búsqueda


# Máximo de acciones por cuenta en una ventana de una hora (documentado en ARQUITECTURA).
POR_HORA = {Accion.busqueda: 10, Accion.consulta_doi: 20, Accion.redaccion: 5}
VENTANA_SEGUNDOS = 3600


class LimiteSuperado(Exception):
    """La cuenta agotó su cupo horario para esta acción."""


class EnCurso(Exception):
    """La cuenta ya tiene una acción de investigación en curso (concurrencia 1 por cuenta)."""


class ProveedorOcupado(Exception):
    """Otra cuenta está consultando Crossref (concurrencia 1 en todo el servidor)."""


class Limitador:
    def __init__(self, reloj=time.monotonic) -> None:
        self._reloj = reloj
        self._cerrojo = threading.Lock()
        self._usos: dict[tuple[int, Accion], deque[float]] = defaultdict(deque)
        self._en_curso: set[int] = set()
        self._crossref = threading.Semaphore(1)

    @contextmanager
    def accion(self, usuario_id: int, accion: Accion, espera_crossref: float = 0):
        """Reserva el cupo y la concurrencia; el cupo se consume aunque la acción falle."""
        ahora = self._reloj()
        with self._cerrojo:
            if usuario_id in self._en_curso:
                raise EnCurso
            usos = self._usos[(usuario_id, accion)]
            while usos and ahora - usos[0] >= VENTANA_SEGUNDOS:
                usos.popleft()
            if len(usos) >= POR_HORA[accion]:
                raise LimiteSuperado
            usos.append(ahora)
            self._en_curso.add(usuario_id)
        usa_crossref = accion in (Accion.busqueda, Accion.consulta_doi)
        try:
            if usa_crossref and not self._crossref.acquire(timeout=espera_crossref):
                raise ProveedorOcupado
            try:
                yield
            finally:
                if usa_crossref:
                    self._crossref.release()
        finally:
            with self._cerrojo:
                self._en_curso.discard(usuario_id)
