# Etapa base para las dependencias
FROM python:3.12-slim-bullseye AS base

ENV PROJECT_ROOT=/usr/fastapi-template
ENV BUILD_DIR=${PROJECT_ROOT}/build/linux/fastapi-template
RUN pip install --upgrade pip
RUN mkdir -p ${PROJECT_ROOT}
WORKDIR ${PROJECT_ROOT}

# Etapa de desarrollo (dev)
# ---
FROM base AS dev

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    nano \
    curl \
    sqlite3 \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Crea el usuario y grupo con UID/GID 1000
RUN groupadd -r dev -g 1000 \
    && useradd -m -r -g dev -u 1000 -d /home/dev -s /bin/bash dev
RUN pip install poetry

# Da permisos al usuario 'dev' sobre el directorio de trabajo
RUN mkdir -p ${PROJECT_ROOT}/.venv
RUN chown -R dev:dev ${PROJECT_ROOT}/

# Copiar como root y dar permisos
COPY --chown=dev:dev docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Asegúrate de marcarlo ejecutable en tu host antes de hacer build:
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
# Cambia al usuario 'dev' para las siguientes etapas
USER dev

ENV PYTHONPATH=${PROJECT_ROOT}/src
ENTRYPOINT ["docker-entrypoint.sh"]
# El comando ahora lee el puerto de la variable de entorno
#CMD poetry run uvicorn app.main:app --reload --host $HOST --port $PORT
CMD ["tail", "-f", "/dev/null"]

# ----------------------------------------------------------------
# Etapa 2: Exporter - Prepara las dependencias de producción
# ----------------------------------------------------------------
FROM base AS poetry-export-deps
RUN pip install poetry
RUN poetry self add poetry-plugin-export
COPY pyproject.toml poetry.lock ./
# Exporta solo las dependencias de producción a requirements.txt
RUN poetry export --without-hashes --without dev -f requirements.txt -o requirements.txt

# ----------------------------------------------------------------
# Etapa 3: Builder - Compila la aplicación con PyInstaller
# ----------------------------------------------------------------
FROM base AS builder-unix

RUN apt-get update && apt-get install -y --no-install-recommends \
    binutils \
    ca-certificates \
    curl \
    bash \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=poetry-export-deps ${PROJECT_ROOT}/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt pyinstaller

# Copia todo el código fuente y los scripts de la carpeta backend
COPY ./ ${PROJECT_ROOT}

# Da permisos de ejecución al script de build y lo ejecuta
RUN chmod +x ${PROJECT_ROOT}/build_unix.sh
RUN ./build_unix.sh
# El resultado estará en ${PROJECT_ROOT}/build/linux/graviton-backend

FROM scratch AS exporter-unix
ENV PROJECT_ROOT=/usr/fastapi-template
ENV BUILD_DIR=${PROJECT_ROOT}/build/linux/fastapi-template

# Copia solo el archivo ejecutable desde la etapa 'builder-unix' a la raíz de esta nueva etapa.
COPY --from=builder-unix ${BUILD_DIR} /

# ----------------------------------------------------------------
# Etapa 4: Runner - Imagen final de producción
# ----------------------------------------------------------------
FROM debian:bullseye-slim AS runner
WORKDIR /app
ENV PROJECT_ROOT=/usr/fastapi-template
ENV BUILD_DIR=${PROJECT_ROOT}/build/linux/fastapi-template

# Crea un usuario no-root para ejecutar la aplicación
RUN groupadd -r userapp -g 1000 \
    && useradd -m -r -g userapp -u 1000 -d /home/userapp -s /bin/bash userapp

# Copia ÚNICAMENTE el directorio con el ejecutable compilado
COPY --from=builder-unix ${BUILD_DIR} /app

# Asigna la propiedad del directorio de la aplicación al nuevo usuario
RUN chown -R userapp:userapp /app

# Cambia al usuario no-root
USER userapp

# El comando para ejecutar la aplicación. Usamos run.sh que maneja el path.
CMD ["./run.sh"]