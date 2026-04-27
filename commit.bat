@echo off
if "%~1"=="" (
    echo [ERROR] Falta el mensaje del commit.
    goto :end
)
set msg=%~1

echo.
echo [1/4] Limpiando carpetas y compilando en modo RELEASE (Normal)...
if exist "apks" rd /s /q "apks"
mkdir "apks"

:: Usamos 'release' en lugar de 'debug'
call flutter build apk --release --split-per-abi

echo.
echo [2/4] Seleccionando APKs de Release ligeros...
:: Los nombres cambian de '-debug.apk' a '-release.apk'
copy "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "apks\" /Y
copy "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "apks\" /Y
copy "build\app\outputs\flutter-apk\app-x86_64-release.apk" "apks\" /Y

echo.
echo [3/4] Haciendo Commit...
git add .
git commit -m "%msg%"

echo.
echo [4/4] Subiendo a GitHub...
git push

echo.
echo [OK] ¡Ahora si que si! Version Release subida sin fantasmas.
:end