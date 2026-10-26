"""Cliente mínimo de la REST API de Crossref y normalización de sus metadatos (Bloque 7C).

Solo se consultan dos rutas fijas de `api.crossref.org`: búsqueda de obras (`/works`) y una obra
por DOI (`/works/{doi}`). No se descargan otras URLs ni se siguen enlaces de las respuestas.

Condiciones (consultadas el 25/10/2026, ver docs/ARQUITECTURA.md → "Referencias"):
- Sin clave. El pool "polite" exige un correo de contacto en `mailto` y en el User-Agent; sin
  `CROSSREF_MAILTO` configurado la búsqueda responde "no configurada".
- Casi ningún metadato está sujeto a derechos de autor; los resúmenes (abstracts) pueden estarlo.
  **No se procesan ni se guardan resúmenes** hasta aprobar una política de licencias.
- Una referencia localizada no certifica calidad ni respalda por sí sola ninguna afirmación.

Las respuestas son datos no confiables: se validan campo a campo y se convierten a texto plano.
"""

import html
import json
import re
import socket
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from enum import Enum
from typing import Protocol

# Límites (documentados en docs/ARQUITECTURA.md).
MAX_RESULTADOS = 10
MAX_CONSULTA = 300  # caracteres enviados como query.bibliographic
MAX_TITULO = 300
MAX_AUTORES = 10
MAX_TEXTO_CORTO = 200

# Patrón recomendado por Crossref para DOI modernos (con mayúsculas o minúsculas).
_PATRON_DOI = re.compile(r"^10\.\d{4,9}/[-._;()/:A-Za-z0-9]+$")
_ETIQUETAS = re.compile(r"<[^>]*>")
_CONTROL = re.compile(r"[\x00-\x1f\x7f]")

# Tipos de Crossref que se distinguen; el resto es "tipo no determinado". Es la clasificación que
# declara el editor, no una valoración de calidad.
TIPOS = {
    "journal-article": "articulo",
    "proceedings-article": "articulo_congreso",
    "book-chapter": "capitulo",
    "book": "libro",
    "monograph": "libro",
    "report": "informe",
    "dataset": "conjunto_datos",
    "posted-content": "preprint",
    "dissertation": "tesis",
}

# Campos pedidos a Crossref (`select`): ni resúmenes ni enlaces a texto completo.
CAMPOS_SELECT = (
    "DOI,title,author,issued,type,container-title,publisher,license,relation"
)


class FalloFuente(Enum):
    NO_CONFIGURADA = "no_configurada"
    CUOTA = "cuota"  # 429 de Crossref
    NO_DISPONIBLE = "no_disponible"  # red, tiempo agotado, 5xx
    MAL_FORMADA = "mal_formada"  # JSON inválido o forma inesperada


class ErrorFuente(Exception):
    def __init__(self, fallo: FalloFuente) -> None:
        super().__init__(fallo.value)
        self.fallo = fallo


class FuenteBibliografica(Protocol):
    def buscar(self, consulta: str) -> list[dict]: ...

    def obra(self, doi: str) -> dict | None: ...


def doi_valido(doi: str) -> str | None:
    """DOI normalizado (sin prefijos de URL, en minúsculas) o None si no es válido."""
    if not isinstance(doi, str):
        return None
    doi = doi.strip()
    for prefijo in ("https://doi.org/", "http://doi.org/", "doi:"):
        if doi.lower().startswith(prefijo):
            doi = doi[len(prefijo):]
    if len(doi) > 200 or not _PATRON_DOI.match(doi):
        return None
    return doi.lower()


def enlace_doi(doi: str) -> str:
    """Único enlace que se guarda y se muestra: HTTPS a doi.org construido desde el DOI."""
    return "https://doi.org/" + urllib.parse.quote(doi, safe="/:;()._-")


def texto_plano(valor: object, maximo: int) -> str | None:
    """Quita etiquetas (JATS/HTML), entidades y caracteres de control; recorta."""
    if not isinstance(valor, str):
        return None
    limpio = _CONTROL.sub(" ", html.unescape(_ETIQUETAS.sub(" ", valor)))
    limpio = " ".join(limpio.split())
    return limpio[:maximo] or None


def _primero(valor: object) -> object:
    return valor[0] if isinstance(valor, list) and valor else None


def _fecha(issued: object) -> str | None:
    """'AAAA', 'AAAA-MM' o 'AAAA-MM-DD' solo con las partes que da Crossref."""
    try:
        partes = issued["date-parts"][0]  # type: ignore[index]
        numeros = [int(p) for p in partes[:3] if p is not None]
    except (KeyError, IndexError, TypeError, ValueError):
        return None
    if not numeros or not 1000 <= numeros[0] <= 2100:
        return None
    return "-".join([f"{numeros[0]:04d}", *[f"{n:02d}" for n in numeros[1:]]])


def _autores(lista: object) -> list[str]:
    nombres = []
    for autor in lista if isinstance(lista, list) else []:
        if not isinstance(autor, dict):
            continue
        partes = [texto_plano(autor.get(k), 100) for k in ("given", "family")]
        nombre = " ".join(p for p in partes if p) or texto_plano(autor.get("name"), 150)
        if nombre:
            nombres.append(nombre)
        if len(nombres) == MAX_AUTORES:
            break
    return nombres


def _licencias(lista: object) -> list[dict]:
    """Licencias declaradas (solo informativas: no autorizan procesar resúmenes)."""
    salida = []
    for lic in lista if isinstance(lista, list) else []:
        if not isinstance(lic, dict):
            continue
        url = lic.get("URL")
        if not isinstance(url, str) or urllib.parse.urlsplit(url).scheme not in ("http", "https"):
            continue
        salida.append(
            {
                "url": url[:300],
                "aplica_a": texto_plano(lic.get("content-version"), 20),
                "inicio": _fecha(lic.get("start")),
            }
        )
    return salida[:5]


def _relacionadas(relacion: object) -> list[dict]:
    """Preprint ↔ versión publicada: la misma obra, no corroboraciones independientes."""
    salida = []
    if not isinstance(relacion, dict):
        return salida
    for tipo in ("is-preprint-of", "has-preprint", "is-version-of", "has-version"):
        for item in relacion.get(tipo) or []:
            if isinstance(item, dict) and item.get("id-type") == "doi":
                doi = doi_valido(str(item.get("id", "")))
                if doi:
                    salida.append({"relacion": tipo, "doi": doi})
    return salida[:10]


def normalizar_obra(item: object, consultada_en: datetime | None = None) -> dict | None:
    """Referencia con metadatos validados, o None si falta DOI válido o título."""
    if not isinstance(item, dict):
        return None
    doi = doi_valido(item.get("DOI", ""))
    titulo = texto_plano(_primero(item.get("title")), MAX_TITULO)
    if doi is None or titulo is None:
        return None
    tipo_crossref = item.get("type") if isinstance(item.get("type"), str) else None
    return {
        "doi": doi,
        "titulo": titulo,
        "autores": _autores(item.get("author")),
        "fecha_publicacion": _fecha(item.get("issued")),
        "tipo": TIPOS.get(tipo_crossref or "", "no_determinado"),
        "tipo_crossref": texto_plano(tipo_crossref, 40),
        "publicacion": texto_plano(_primero(item.get("container-title")), MAX_TEXTO_CORTO),
        "editorial": texto_plano(item.get("publisher"), MAX_TEXTO_CORTO),
        "licencias": _licencias(item.get("license")),
        "relacionadas": _relacionadas(item.get("relation")),
        "enlace": enlace_doi(doi),
        "procedencia": "crossref",
        "consultada_en": (consultada_en or datetime.now(timezone.utc)).isoformat(),
    }


def agrupar(referencias: list[dict]) -> list[dict]:
    """Quita DOI repetidos y marca las que Crossref relaciona entre sí (misma obra)."""
    vistas: dict[str, dict] = {}
    for ref in referencias:
        vistas.setdefault(ref["doi"], ref)
    dois = set(vistas)
    for ref in vistas.values():
        ref["misma_obra_que"] = sorted(
            {r["doi"] for r in ref["relacionadas"] if r["doi"] in dois and r["doi"] != ref["doi"]}
        )
    return list(vistas.values())


class CrossrefCliente:
    def __init__(self, mailto: str, base_url: str, timeout_segundos: float) -> None:
        self._mailto = mailto
        self._base = base_url.rstrip("/")
        self._timeout = timeout_segundos
        self._agente = f"AgoraJoven/1.1 (proyecto educativo; mailto:{mailto})"

    def _pedir(self, ruta: str, parametros: dict[str, str]) -> object:
        url = f"{self._base}{ruta}?" + urllib.parse.urlencode({**parametros, "mailto": self._mailto})
        peticion = urllib.request.Request(
            url, headers={"User-Agent": self._agente, "Accept": "application/json"}
        )
        try:
            with urllib.request.urlopen(peticion, timeout=self._timeout) as respuesta:
                return json.loads(respuesta.read(2_000_000).decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            fallo = FalloFuente.CUOTA if e.code == 429 else FalloFuente.NO_DISPONIBLE
            raise ErrorFuente(fallo) from None
        except (urllib.error.URLError, socket.timeout, TimeoutError, ConnectionError):
            raise ErrorFuente(FalloFuente.NO_DISPONIBLE) from None
        except (ValueError, UnicodeDecodeError):
            raise ErrorFuente(FalloFuente.MAL_FORMADA) from None

    def buscar(self, consulta: str) -> list[dict]:
        datos = self._pedir(
            "/works",
            {
                "query.bibliographic": consulta[:MAX_CONSULTA],
                "rows": str(MAX_RESULTADOS),
                "select": CAMPOS_SELECT,
            },
        )
        try:
            items = datos["message"]["items"]  # type: ignore[index]
        except (KeyError, TypeError):
            raise ErrorFuente(FalloFuente.MAL_FORMADA) from None
        if not isinstance(items, list):
            raise ErrorFuente(FalloFuente.MAL_FORMADA)
        return items

    def obra(self, doi: str) -> dict | None:
        datos = self._pedir("/works/" + urllib.parse.quote(doi, safe=""), {})
        if datos is None:
            return None
        try:
            item = datos["message"]  # type: ignore[index]
        except (KeyError, TypeError):
            raise ErrorFuente(FalloFuente.MAL_FORMADA) from None
        return item if isinstance(item, dict) else None
