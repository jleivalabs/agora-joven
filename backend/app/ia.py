"""Proveedor de IA del asistente: cliente REST mínimo de la Gemini API.

Se usa la biblioteca estándar (urllib) en lugar de un SDK para no añadir dependencias. Este
módulo no registra la clave, los prompts ni las respuestas.

Referencia (consultada el 24/10/2026): POST
{base}/v1beta/models/{modelo}:generateContent con la cabecera x-goog-api-key.
"""

import json
import socket
import urllib.error
import urllib.request
from dataclasses import dataclass
from enum import Enum
from typing import Protocol

from pydantic import SecretStr

# finishReason con los que se acepta el texto generado. MAX_TOKENS se acepta marcado como truncado.
_FIN_NORMAL = {"STOP"}
_FIN_TRUNCADO = {"MAX_TOKENS"}


class FalloProveedor(Enum):
    CUOTA = "cuota"  # 429 del proveedor
    NO_DISPONIBLE = "no_disponible"  # red, tiempo agotado, 5xx o configuración rechazada
    SIN_RESPUESTA = "sin_respuesta"  # vacía, bloqueada o con forma inesperada


class ErrorProveedor(Exception):
    def __init__(self, fallo: FalloProveedor) -> None:
        super().__init__(fallo.value)
        self.fallo = fallo


@dataclass(frozen=True)
class RespuestaIA:
    texto: str
    truncado: bool


class ProveedorIA(Protocol):
    def generar(self, instrucciones: str, contenido: str) -> RespuestaIA: ...


class ProveedorRedaccion(Protocol):
    """Redacción del Bloque 7C: misma API, sin herramientas (sin búsqueda) y salida JSON."""

    def redactar(self, instrucciones: str, contenido: str, esquema: dict) -> RespuestaIA: ...


class GeminiProveedor:
    def __init__(
        self,
        clave: SecretStr,
        modelo: str,
        timeout_segundos: float,
        base_url: str = "https://generativelanguage.googleapis.com",
        max_tokens_salida: int = 1024,
    ) -> None:
        self._clave = clave
        self._url = f"{base_url.rstrip('/')}/v1beta/models/{modelo}:generateContent"
        self._timeout = timeout_segundos
        self._max_tokens = max_tokens_salida

    def generar(self, instrucciones: str, contenido: str) -> RespuestaIA:
        return self._llamar(instrucciones, contenido, {})

    def redactar(self, instrucciones: str, contenido: str, esquema: dict) -> RespuestaIA:
        """Salida estructurada sin `tools`: no se usa Grounding with Google Search."""
        return self._llamar(
            instrucciones,
            contenido,
            {"responseMimeType": "application/json", "responseSchema": esquema},
        )

    def _llamar(self, instrucciones: str, contenido: str, extra: dict) -> RespuestaIA:
        cuerpo = {
            "systemInstruction": {"parts": [{"text": instrucciones}]},
            "contents": [{"role": "user", "parts": [{"text": contenido}]}],
            "generationConfig": {
                "maxOutputTokens": self._max_tokens,
                "temperature": 0.3,
                **extra,
            },
        }
        peticion = urllib.request.Request(
            self._url,
            data=json.dumps(cuerpo).encode("utf-8"),
            method="POST",
            headers={
                "Content-Type": "application/json",
                "x-goog-api-key": self._clave.get_secret_value(),
            },
        )
        try:
            with urllib.request.urlopen(peticion, timeout=self._timeout) as respuesta:
                datos = json.loads(respuesta.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            fallo = FalloProveedor.CUOTA if e.code == 429 else FalloProveedor.NO_DISPONIBLE
            raise ErrorProveedor(fallo) from None
        except (urllib.error.URLError, socket.timeout, TimeoutError, ConnectionError):
            raise ErrorProveedor(FalloProveedor.NO_DISPONIBLE) from None
        except (ValueError, UnicodeDecodeError):
            raise ErrorProveedor(FalloProveedor.SIN_RESPUESTA) from None
        return interpretar_respuesta(datos)


def interpretar_respuesta(datos: object) -> RespuestaIA:
    """Extrae el texto de una respuesta de generateContent o lanza SIN_RESPUESTA."""
    try:
        if datos.get("promptFeedback", {}).get("blockReason"):  # type: ignore[union-attr]
            raise ErrorProveedor(FalloProveedor.SIN_RESPUESTA)
        candidato = datos["candidates"][0]  # type: ignore[index]
        fin = candidato.get("finishReason", "STOP")
        if fin not in _FIN_NORMAL | _FIN_TRUNCADO:
            raise ErrorProveedor(FalloProveedor.SIN_RESPUESTA)
        partes = candidato["content"]["parts"]
        texto = "".join(p.get("text", "") for p in partes if not p.get("thought")).strip()
    except ErrorProveedor:
        raise
    except (AttributeError, KeyError, IndexError, TypeError):
        raise ErrorProveedor(FalloProveedor.SIN_RESPUESTA) from None
    if not texto:
        raise ErrorProveedor(FalloProveedor.SIN_RESPUESTA)
    return RespuestaIA(texto=texto, truncado=fin in _FIN_TRUNCADO)
