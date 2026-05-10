@echo off
if "%~1"=="" (
    echo [ERROR] Falta el mensaje del commit.
    goto :end
)
set msg=%~1

echo.
echo [0/5] Sincronizando codigo de la API desde el servidor...
:: /MIR hace un espejo (borra lo que no este en el origen y copia lo nuevo)
:: /XD .git evita problemas si hubiera un git en el destino
if not exist "API" mkdir "API"
robocopy "\\192.168.1.224\html\api" "API" /MIR /R:2 /W:5 /NP /NDL /NFL

echo.
echo [1/5] Limpiando carpetas y compilando en modo RELEASE...
if exist "apks" rd /s /q "apks"
mkdir "apks"

:: Compilamos la version final para el movil
call flutter build apk --release --split-per-abi

echo.
echo [2/5] Seleccionando APKs de Release...
copy "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "apks\" /Y
copy "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "apks\" /Y
copy "build\app\outputs\flutter-apk\app-x86_64-release.apk" "apks\" /Y

echo.
echo [3/5] Haciendo Commit de App y API...
git add .
git commit -m "%msg%"

echo.
echo [4/5] Subiendo a GitHub...
git push origin main

echo.
echo [OK] ¡Sincronizado! App (Release) y API guardadas en el repositorio.
:end