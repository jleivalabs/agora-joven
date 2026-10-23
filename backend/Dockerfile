FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /srv

# Dependencias primero: esta capa se reutiliza mientras no cambie requirements.txt.
COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY app/ ./app/

# No ejecutar como root. /srv/data es el punto de montaje del volumen de SQLite: al crearse
# el volumen por primera vez hereda este propietario, así que agora puede escribir en él.
RUN useradd --create-home agora && mkdir -p /srv/data && chown -R agora:agora /srv
USER agora

EXPOSE 8000

CMD ["uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000"]
