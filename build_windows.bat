@echo off
setlocal
echo Creating Windows executable...

REM Limpia la variable por si existía antes
SET "SPEC_BASENAME="

REM Busca cualquier archivo .spec en el directorio actual
REM %%F es el nombre del archivo encontrado (ej: "mi_archivo.spec")
FOR %%F IN (*.spec) DO (
    SET "SPEC_BASENAME=%%~nF"
)

REM Comprueba si la variable fue establecida (es decir, si se encontró un archivo)
IF DEFINED SPEC_BASENAME (
    ECHO Se encontró el archivo: %SPEC_BASENAME%
) ELSE (
    ECHO No se encontró ningún archivo .spec en este directorio.
)

REM --- 1. Definir rutas ---
REM El directorio 'build' se crea al lado del .bat
SET SCRIPT_DIR=%~dp0
SET BUILD_DIR=build\windows\
SET DIST_DIR=%SCRIPT_DIR%dist\
SET OUTPUT_DIR=%SCRIPT_DIR%%BUILD_DIR%%SPEC_BASENAME%
SET TEMP_DIR=%SCRIPT_DIR%build\windows\temp

REM Limpiar compilaciones anteriores
if exist "%DIST_DIR%" rmdir /S /Q "%DIST_DIR%"
if exist "%OUTPUT_DIR%" rmdir /S /Q "%OUTPUT_DIR%"
if exist "%TEMP_DIR%" rmdir /S /Q "%TEMP_DIR%"
if exist dist rmdir /S /Q dist
if exist build rmdir /S /Q build

REM --- 2. Construir con PyInstaller especificando rutas ---
echo Building with PyInstaller...
REM Usamos --distpath y --workpath para forzar las carpetas de salida
pyinstaller --clean --distpath "%OUTPUT_DIR%" --workpath "%TEMP_DIR%" "%SPEC_BASENAME%".spec

REM --- NUEVO: Verificación de errores ---
if %errorlevel% neq 0 (
    echo.
    echo =========================
    echo  PYINSTALLER FAILED!
    echo =========================
    echo Build stopped due to errors.
    exit /b %errorlevel%
)

echo Executable created in "%OUTPUT_DIR%"

REM ... (El resto de tus scripts start.bat/run.bat) ...
REM (Asegúrate de que las rutas en esos scripts apunten a %OUTPUT_DIR%)
echo @echo off > "%OUTPUT_DIR%\start.bat"
echo cd /d "%%~dp0" >> "%OUTPUT_DIR%\start.bat"
echo set PYTHONPATH=%%CD%% >> "%OUTPUT_DIR%\start.bat"
echo echo Starting GravitonAI Backend... >> "%OUTPUT_DIR%\start.bat"
echo graviton-backend.exe >> "%OUTPUT_DIR%\start.bat"
echo pause >> "%OUTPUT_DIR%\start.bat"

echo @echo off > "%OUTPUT_DIR%\run.bat"
echo cd /d "%%~dp0" >> "%OUTPUT_DIR%\run.bat"
echo set PYTHONPATH=%%CD%% >> "%OUTPUT_DIR%\run.bat"
echo graviton-backend.exe >> "%OUTPUT_DIR%\run.bat"

echo Build Windows completado.
echo Run with: "%OUTPUT_DIR%\start.bat"
endlocal