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

# No ejecutar como root.
RUN useradd --create-home agora && chown -R agora:agora /srv
USER agora

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
