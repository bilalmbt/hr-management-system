@echo off
setlocal

where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo.
    echo Docker was not found on this PC.
    echo.
    echo Please install "Docker Desktop" from:
    echo     https://www.docker.com/products/docker-desktop
    echo Launch it once, wait until the whale icon says
    echo "Docker Desktop is running", then double-click this file again.
    echo.
    pause
    exit /b 1
)

echo ============================================================
echo  Starting the HR Tool.
echo  The FIRST run downloads and builds everything and can take
echo  several minutes. It is NOT frozen - watch the lines scroll.
echo  Keep this window open while you use the app.
echo ============================================================
echo.

start "" http://localhost:8000
docker compose up --build

echo.
echo The app has stopped. To run it again, double-click start.bat.
echo Your data is kept. To open the app:  http://localhost:8000
pause
