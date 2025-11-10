#!/bin/bash
set -e

# --- 1. Detectar Sistema Operativo ---
if [ "$(uname)" == "Darwin" ]; then
    OS_NAME="macos"
    OS_DISPLAY_NAME="macOS"
elif [ "$(uname)" == "Linux" ]; then
    OS_NAME="linux"
    OS_DISPLAY_NAME="Linux"
else
    echo "ERROR: Sistema operativo no compatible: $(uname)"
    exit 1
fi

echo "Creando ejecutable para $OS_DISPLAY_NAME..."

# --- 2. Detectar archivo .spec (Lógica portada de build_windows.bat) ---
# Busca el primer archivo .spec en el directorio actual
SPEC_FILENAME=$(find . -maxdepth 1 -name "*.spec" | head -n 1)

# Comprobar si se encontró un archivo
if [ -z "$SPEC_FILENAME" ]; then
    echo "ERROR: No se encontró ningún archivo .spec en este directorio."
    exit 1
fi

# Quitar el './' inicial si 'find' lo añade
SPEC_FILENAME=${SPEC_FILENAME#./}

# Obtener el nombre base (ej: "graviton-backend" de "graviton-backend.spec")
SPEC_BASENAME=$(basename "$SPEC_FILENAME" .spec)
echo "Se encontró el archivo: $SPEC_FILENAME (Basename: $SPEC_BASENAME)"


# --- 3. Definir rutas (Ahora dinámicas) ---
# Obtenemos el directorio absoluto del script
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# Directorio de salida temporal de PyInstaller
PYINSTALLER_DIST_DIR="$SCRIPT_DIR/build/$OS_NAME"
# Directorio de trabajo temporal de PyInstaller
BUILD_DIR="$SCRIPT_DIR/build/$OS_NAME/tmp"
# Directorio de salida final, ahora usa el basename
OUTPUT_DIR="$SCRIPT_DIR/build/$OS_NAME/$SPEC_BASENAME"


# --- 4. Limpiar compilaciones anteriores (Lógica portada de build_windows.bat) [cite: 2] ---
echo "Limpiando directorios anteriores..."
# Limpia toda la carpeta de build y dist, igual que el script de Windows
rm -rf "$SCRIPT_DIR/build"
rm -rf "$SCRIPT_DIR/dist"
# Limpia las carpetas por defecto de PyInstaller si se crean fuera
rm -rf dist
rm -rf build


# --- 5. Construir con PyInstaller ---
echo "Construyendo con PyInstaller..."
# Usamos --distpath y --workpath para forzar las carpetas de salida
pyinstaller --clean --distpath "$OUTPUT_DIR" --workpath "$BUILD_DIR" "$SPEC_FILENAME"

# --- NUEVO: Verificación de errores (Lógica portada de build_windows.bat)  ---
if [ $? -ne 0 ]; then
    echo ""
    echo "========================="
    echo "  PYINSTALLER FAILED!"
    echo "========================="
    echo "Build stopped due to errors."
    exit 1 # [cite: 4]
fi


# --- 6. Organizar archivos finales ---
# El ejecutable estará en $PYINSTALLER_DIST_DIR/$SPEC_BASENAME
echo "Ejecutable creado en '$PYINSTALLER_DIST_DIR/$SPEC_BASENAME'"

# Script de arranque con pausa
cat << EOF > "$OUTPUT_DIR/start.sh"
#!/bin/bash
cd "\$(dirname "\$0")"
export PYTHONPATH=\$(pwd)
echo "Iniciando $SPEC_BASENAME..."
./"$SPEC_BASENAME"
read -p "Presiona ENTER para salir..."
EOF
chmod +x "$OUTPUT_DIR/start.sh"

# Script simple de ejecución sin pausa
cat << EOF > "$OUTPUT_DIR/run.sh"
#!/bin/bash
cd "\$(dirname "\$0")"
export PYTHONPATH=\$(pwd)
./"$SPEC_BASENAME"
EOF
chmod +x "$OUTPUT_DIR/run.sh"

# Permiso de ejecución al binario principal
chmod +x "$OUTPUT_DIR/$SPEC_BASENAME"

echo "Build $OS_DISPLAY_NAME completado."
echo "Ejecuta con: $OUTPUT_DIR/start.sh" # [cite: 5]