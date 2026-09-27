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
echo [1/6] Generando nueva version automatica...
:: Obtenemos el timestamp en formato YYYYMMDDHHmmss mediante PowerShell
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMddHHmmss'"') do set TIMESTAMP=%%a
set NUEVA_VERSION=1.0.%TIMESTAMP%
echo [INFO] Nueva version generada: %NUEVA_VERSION%

:: A. Modificamos pubspec.yaml antes de compilar
powershell -NoProfile -Command "(Get-Content pubspec.yaml) -replace '^version:\s*.*', 'version: %NUEVA_VERSION%+1' | Set-Content pubspec.yaml"

:: B. Modificamos novedades.json en local y lo replicamos al servidor web
powershell -NoProfile -Command ^
  "$path = 'API\docs\novedades.json'; " ^
  "if (Test-Path $path) { " ^
  "  $json = Get-Content $path -Raw | ConvertFrom-Json; " ^
  "  $json.version_ultima = '%NUEVA_VERSION%'; " ^
  "  $json | ConvertTo-Json -Depth 5 | Set-Content $path; " ^
  "  Copy-Item $path '\\192.168.1.224\html\api\docs\novedades.json' -Force; " ^
  "}"

echo.
echo [2/6] Limpiando carpetas y compilando en modo RELEASE...
if exist "apks" rd /s /q "apks"
mkdir "apks"

:: Compilamos con la nueva version ya inyectada
call flutter build apk --release --target-platform android-arm64 --split-per-abi

echo.
echo [3/6] Seleccionando APK de Release...
copy "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "apks\" /Y

echo.
echo [4/6] Haciendo Commit de App y API...
git add .
git commit -m "%msg% [Version %NUEVA_VERSION%]"

echo.
echo [5/6] Subiendo a GitHub...
git push origin main

echo.
echo [OK] Sincronizado. Version %NUEVA_VERSION% compilada y publicada.
:end