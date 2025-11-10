#!/bin/sh
set -eu

# Paths
WORKSPACE="/usr/fastapi-template"
PROJECT_FOLDER="/usr/fastapi-template"
PYPROJECT_TOML="${PROJECT_FOLDER}/pyproject.toml"
POETRY_LOCK="${PROJECT_FOLDER}/poetry.lock"
VENV="${PROJECT_FOLDER}/.venv"
HASH_FILE="${VENV}/.dependencies-hash"

# Calculate combined hash of pyproject.toml and poetry.lock
calculate_hash() {
  if [ ! -f "$PYPROJECT_TOML" ] && [ ! -f "$POETRY_LOCK" ]; then
    # Ensure something unique so install triggers if no files exist
    echo "no-deps-files-$(date +%s)"
    return
  fi
  cat "$PYPROJECT_TOML" "$POETRY_LOCK" 2>/dev/null | sha256sum | cut -d' ' -f1
}

cd "${PROJECT_FOLDER}"

# Ensure poetry creates venv in-project
poetry config virtualenvs.in-project true >/dev/null 2>&1 || true

# Ensure VENV dir exists (after first install)
STORED_HASH=""
if [ -f "$HASH_FILE" ]; then
  STRORED_HASH_CONTENT=$(cat "$HASH_FILE" 2>/dev/null || true)
  STORED_HASH="${STRORED_HASH_CONTENT:-}"
fi

CURRENT_HASH=$(calculate_hash)

if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
  echo ">> Dependencias han cambiado o no se han instalado. Instalando con Poetry..."
  # actualizar lockfile si hace falta y luego instalar
  poetry lock || true
  # Instala en .venv dentro del proyecto (con --no-root evita instalar el paquete como editable)
  poetry install --no-root --with dev
  mkdir -p "$(dirname "$HASH_FILE")"
  echo "$CURRENT_HASH" > "$HASH_FILE"
else
  echo ">> Las dependencias están actualizadas. Saltando instalación."
fi

# Activate the .venv by exporting VIRTUAL_ENV and adjusting PATH.
# Esto hace que el proceso que vamos a exec herede el entorno del venv.
if [ -d "$VENV" ] && [ -x "$VENV/bin/python" ]; then
  echo ">> Activando virtualenv en: $VENV"
  # Set VIRTUAL_ENV for programs that check it
  export VIRTUAL_ENV="$VENV"
  # Put venv bin at front of PATH
  export PATH="$VENV/bin:$PATH"
  # Optional: set PYTHONHOME unset (sometimes recommended)
  unset PYTHONHOME || true
else
  echo ">> Atención: no se encontró virtualenv en $VENV. Se continuará igual (pero puede fallar)."
fi

# Execute the given command using the venv's binaries (no poetry run).
# Example: si llamas al contenedor como `docker run ... uvicorn app.main:app --host 0.0.0.0`,
# el exec correrá uvicorn desde .venv/bin/uvicorn si existe.
echo ">> Ejecutando: $@"
exec "$@"