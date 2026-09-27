@echo off
if "%~1"=="" (
    echo [ERROR] Falta el mensaje del commit.
    goto :end
)
set msg=%~1

echo.
echo [0/6] Sincronizando codigo de la API desde el servidor...
if not exist "API" mkdir "API"
robocopy "\\192.168.1.224\html\api" "API" /MIR /R:2 /W:5 /NP /NDL /NFL

echo.
echo [1/6] Generando nueva version automatica usando Dart...
call dart run update_version.dart

:: Copiamos el JSON actualizado a la ruta de red
copy /Y "API\docs\options.json" "\\192.168.1.224\html\api\docs\options.json" >nul

echo.
echo [2/6] Limpiando carpetas y compilando en modo RELEASE...
if exist "apks" rd /s /q "apks"
mkdir "apks"

:: Detenemos el demonio de Gradle correctamente entrando en su carpeta
cd android
call gradlew.bat --stop
cd ..

call flutter build apk --release --target-platform android-arm64 --split-per-abi --no-pub
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] La compilacion ha fallado. Se cancela el commit y la subida.
    goto :end
)

echo.
echo [3/6] Seleccionando APK de Release...
copy "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "apks\" /Y

echo.
echo [4/6] Haciendo Commit de App y API...
git add .
git commit -m "%msg%"

echo.
echo [5/6] Subiendo a GitHub...
git push origin main

echo.
echo [OK] Sincronizado y compilado con exito.
:end