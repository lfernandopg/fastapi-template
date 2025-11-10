# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_data_files, collect_submodules, collect_all
import os
import glob
import shutil
import platform
import inspect

block_cipher = None

# Usar __file__ para obtener el directorio del .spec de forma fiable
spec_dir = SPECPATH

# Directorio de salida dinámico
output_dir = DISTPATH
spec_file = inspect.getfile(inspect.currentframe())
spec_name = os.path.basename(spec_file)
bin_name = os.path.splitext(spec_name)[0]

print("="*60)
print("PyInstaller Build Configuration (Modo One-File)")
print("="*60)
print(f"Spec directory (spec_dir): {spec_dir}")

# --- Inicio de la lógica de backend.spec ---

# Collect all relevant packages
all_hiddenimports = []
all_datas = []

# Collect FastAPI and its dependencies
print("\n[1/6] Collecting FastAPI dependencies...")
for module in ['fastapi', 'starlette', 'pydantic', 'uvicorn']:
    try:
        module_imports, module_datas, module_binaries = collect_all(module)
        if module_imports:
            all_hiddenimports.extend([imp for imp in module_imports if isinstance(imp, str)])
        if module_datas:
            for data in module_datas:
                if isinstance(data, tuple) and len(data) == 2 and data[0] != 'data':
                    all_datas.append(data)
        print(f"{module}")
    except Exception as e:
        print(f"Warning: Could not collect data for {module}: {e}")

# Add specific imports for uvicorn that might be missed
print("\n[2/6] Adding uvicorn and database imports...")
all_hiddenimports.extend([
    'uvicorn.logging',
    'uvicorn.lifespan',
    'uvicorn.lifespan.on',
    'uvicorn.lifespan.off',
    'uvicorn.protocols',
    'uvicorn.protocols.http',
    'uvicorn.protocols.http.auto',
    'uvicorn.protocols.websockets',
    'uvicorn.protocols.websockets.auto',
    'aiosqlite',
])

# Add SQLAlchemy and Alembic packages (CRITICAL for migrations)
all_hiddenimports.extend([
    'sqlalchemy',
    'sqlalchemy.ext.declarative',
    'sqlalchemy.ext.asyncio',
    'sqlalchemy.orm',
    'sqlalchemy.orm.decl_api',
    'sqlalchemy.pool',
    'sqlalchemy.engine',
    'alembic',
    'alembic.command',
    'alembic.config',
    'alembic.runtime',
    'alembic.runtime.migration',
    'alembic.runtime.environment',
    'alembic.script',
    'alembic.script.base',
    'alembic.operations',
    'alembic.operations.ops',
    'alembic.ddl',
    'alembic.ddl.impl',
    'alembic.ddl.sqlite',
    'alembic.autogenerate',
])
print("Database and migration imports added")

# Add loguru and other dependencies
all_hiddenimports.extend(['loguru'])

# Collect all submodules from your project packages
print("\n[3/6] Collecting project submodules...")
try:
    apps_submodules = collect_submodules('apps')
    infrastructure_submodules = collect_submodules('infrastructure')
    
    if apps_submodules:
        all_hiddenimports.extend([mod for mod in apps_submodules if isinstance(mod, str)])
        print(f"apps.* ({len(apps_submodules)} modules)")
    if infrastructure_submodules:
        all_hiddenimports.extend([mod for mod in infrastructure_submodules if isinstance(mod, str)])
        print(f"infrastructure.* ({len(infrastructure_submodules)} modules)")
except Exception as e:
    print(f"Warning: Could not collect submodules: {e}")

# (Sección 4/6 y 5/6 omitidas en el original, continuando con la lógica de datos)

# Ensure all data entries are properly formatted tuples of exactly 2 elements
validated_datas = []
for entry in all_datas:
    if isinstance(entry, tuple) and len(entry) == 2:
        src, dest = entry
        if isinstance(src, str) and isinstance(dest, str):
            validated_datas.append((src, dest))
    elif isinstance(entry, str):
        validated_datas.append((entry, entry))

# Remove duplicates while preserving order (para datas)
seen = set()
final_datas = []
for item in validated_datas:
    if item not in seen:
        seen.add(item)
        final_datas.append(item)

# Remove duplicates from hiddenimports and ensure all are strings
all_hiddenimports = list(set([imp for imp in all_hiddenimports if isinstance(imp, str) and imp]))

print("\n[6/6] Build summary:")
print(f"  Total hiddenimports: {len(all_hiddenimports)}")
print(f"  Total data files: {len(final_datas)}")
print("\n" + "="*60)
print("Starting PyInstaller Analysis...")
print("="*60 + "\n")

# --- Fin de la lógica de backend.spec ---

# --- Definición del Análisis (de backend.spec) ---
a = Analysis(
    ['src/app/main.py'],
    pathex=[os.path.join(spec_dir, 'src')],  # Usar spec_dir
    binaries=[], # Los binarios se manejan en el EXE
    datas=final_datas, # Usar los datas recopilados
    hiddenimports=all_hiddenimports, # Usar los hiddenimports recopilados
    hookspath=[os.path.join(spec_dir, 'hooks')],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

# --- Definición de PYZ (de backend.spec) ---
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# Esta es la sección clave.
# Usamos la estructura de EXE de main.spec (que crea un solo archivo)
# pero pasamos a.binaries y a.datas para incluir todo DENTRO del exe.
exe = EXE(
    pyz,
    a.scripts,
    a.binaries,  # <-- Importante: Incluir binarios en el EXE
    a.datas,     # <-- Importante: Incluir datas en el EXE
    [],
    name=bin_name, # Nombre de backend.spec
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    #console=True,   #Para Desarrollo
    console=False, # Para ejecutable
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None
)

# No incluimos el objeto 'coll = COLLECT(...)' para forzar el modo "one-file".

extra_files = [
    "alembic.ini",
    #".env",
]

print("\n" + "="*60)
print(f"Copiando archivos externos a: {output_dir}")

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

for f in extra_files:
    src = os.path.join(spec_dir, f)
    build = os.path.join(output_dir, f)
    if os.path.exists(src):
        print(f"Copiando {f}...")
        shutil.copy2(src, build)
    else:
        print(f"Advertencia: No se encontró {src} para copiar.")

# Copiar la carpeta alembic completa
src_alembic = os.path.join(spec_dir, "alembic")
build_alembic = os.path.join(output_dir, "alembic")
if os.path.exists(src_alembic):
    print("Copiando carpeta 'alembic'...")
    if os.path.exists(build_alembic):
        shutil.rmtree(build_alembic)
    shutil.copytree(src_alembic, build_alembic)
else:
     print(f"Advertencia: No se encontró la carpeta {src_alembic} para copiar.")

print("\n" + "="*60)
print("PyInstaller build (one-file) configuration completed!")
print("="*60)