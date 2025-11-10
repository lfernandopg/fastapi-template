# Nombre del archivo docker-compose principal
COMPOSE_FILE := docker-compose.yml

# Directorios de salida para los artefactos
APP_NAME := /fastapi-template
LINUX_BUILD_DIR := build/linux
WINDOWS_BUILD_DIR := build/windows

# Definimos las rutas de salida completas para los artefactos
LINUX_APP_DIR := $(LINUX_BUILD_DIR)$(APP_NAME)
WINDOWS_APP_DIR := $(WINDOWS_BUILD_DIR)$(APP_NAME)

# --- Variables para exportación de Windows ---
IMAGE_WINDOWS_NAME := fastapi-template-windows
CONTAINER_WINDOWS_NAME := fastapi-template-build
PATH_IN_CONTAINER:= $(APP_NAME)

# --- (NUEVO) Variables para exportación de Linux ---
IMAGE_LINUX_NAME := fastapi-template-linux
CONTAINER_LINUX_NAME := fastapi-template-build-linux
# Esta ruta debe coincidir con el nuevo destino del COPY en la etapa exporter-unix
PATH_IN_LINUX_CONTAINER := /fastapi-template


# Asegura que los targets se ejecuten aunque existan archivos con esos nombres
.PHONY: up-dev down-dev build-dev logs-dev up-prod down-prod build-prod logs-prod ps clean export-unix export-windows export-all

# ============================
# Detección de OS para comandos cross-platform
# ============================
# Define comandos seguros para limpieza y creación de directorios
# que no fallan si el directorio existe o no existe.
# ¡¡CORRECCIÓN AQUÍ!! Estas líneas NO deben estar indentadas.
ifeq ($(OS),Windows_NT)
# Comandos de Windows (CMD/Powershell)
# Usamos una sub-shell para ignorar errores si no existe y suprimir salida
CLEAN_DIR = @(if exist "$(subst /,\,$1)" ( rmdir /s /q "$(subst /,\,$1)" )) 2>NUL || (exit 0)
# Asegura que el directorio exista
MKDIR_P = @(if not exist "$(subst /,\,$1)" ( md "$(subst /,\,$1)" )) 2>NUL || (exit 0)
else
# Comandos de Unix (bash/sh/zsh)
CLEAN_DIR = @rm -rf "$1"
MKDIR_P = @mkdir -p "$1"
endif

# ============================
# Desarrollo
# ============================
up-dev:
	docker compose -f $(COMPOSE_FILE) --profile dev up

down-dev:
	docker compose -f $(COMPOSE_FILE) --profile dev down

build-dev:
	docker compose -f $(COMPOSE_FILE) --profile dev build

logs-dev:
	docker compose -f $(COMPOSE_FILE) --profile dev logs -f

# ============================
# Producción
# ============================
up-prod:
	docker compose -f $(COMPOSE_FILE) --profile prod up

down-prod:
	docker compose -f $(COMPOSE_FILE) --profile prod down

build-prod:
	docker compose -f $(COMPOSE_FILE) --profile prod build

logs-prod:
	docker compose -f $(COMPOSE_FILE) --profile prod logs -f

# ============================
# Exportar Artefactos (Binarios)
# ============================

# Target para exportar el binario de Unix
export-linux:
	@echo "Limpiando directorio de Linux anterior..."
	$(call CLEAN_DIR,$(LINUX_APP_DIR))
	@echo "Exportando binario de Linux..."

ifeq ($(OS),Windows_NT)
# --- Estrategia de Windows (docker cp) ---
	@echo "Usando estrategia de compatibilidad (docker cp) en Windows..."
# 1. Asegura que el directorio padre exista 
	$(call MKDIR_P,$(LINUX_BUILD_DIR))
# 2. Construye la imagen (apuntando al target exporter-unix)
	docker build --target exporter-unix -t $(IMAGE_LINUX_NAME) .
# 3. Crea el contenedor 
	docker create --name $(CONTAINER_LINUX_NAME) $(IMAGE_LINUX_NAME)
# 4. Copia el artefacto
	docker cp $(CONTAINER_LINUX_NAME):$(PATH_IN_LINUX_CONTAINER) $(LINUX_BUILD_DIR)
# 5. Limpia el contenedor
	docker rm $(CONTAINER_LINUX_NAME)
else
# --- Estrategia de Linux (docker build --output) ---
	@echo "Usando estrategia nativa de Linux (docker build --output)..."
# docker build --output creará el directorio de destino automáticamente 
	docker build --target exporter-unix --output type=local,dest=$(LINUX_APP_DIR) .
endif

	@echo "Binario de Linux exportado a $(LINUX_APP_DIR)/"

# Target para exportar el binario de Windows
export-windows:
	@echo "Limpiando directorio de Windows anterior..."
# 1. Limpia el directorio final de la app si existe 
	$(call CLEAN_DIR,$(WINDOWS_APP_DIR))
# 2. Asegura que el directorio *padre* exista (requerido por docker cp) 
	$(call MKDIR_P,$(WINDOWS_BUILD_DIR))
	@echo "Exportando binario de Windows..."
	@docker info | findstr "OSType: windows"  || (echo "ERROR: Docker no esta en modo Windows." && echo "Haz clic derecho en Docker > 'Switch to Windows containers...'" && exit /b 1)
	docker build -f Dockerfile.windows -t $(IMAGE_WINDOWS_NAME) .
	docker create --name $(CONTAINER_WINDOWS_NAME) $(IMAGE_WINDOWS_NAME) 
# docker cp copia $(PATH_IN_CONTAINER) DENTRO de $(WINDOWS_BUILD_DIR)
	docker cp $(CONTAINER_WINDOWS_NAME):$(PATH_IN_CONTAINER) $(WINDOWS_BUILD_DIR)
	@echo "Binario de Windows exportado a $(WINDOWS_APP_DIR)/"
	docker rm $(CONTAINER_WINDOWS_NAME)


# ============================
# Generales
# ============================
ps:
	docker compose -f $(COMPOSE_FILE) ps

clean:
	docker system prune -f
	@echo "Limpiando directorios de build..."
# Usa el comando cross-platform para limpiar el directorio padre 'backend/build'
	$(call CLEAN_DIR,backend/build)