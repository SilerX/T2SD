@echo off
setlocal
cd /d "%~dp0\.."

if exist ".git" (
  echo [INFO] Repositorio git ya inicializado
) else (
  git init -b main
  echo [OK] git init
)

git add .
git commit -m "Tarea 2: Procesamiento y Fallback con Apache Kafka"

echo.
echo Para subir a GitHub:
echo   git remote add origin URL_DEL_REPO
echo   git push -u origin main
endlocal
