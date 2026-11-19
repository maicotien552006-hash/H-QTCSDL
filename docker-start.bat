@echo off
title OISM - Khoi Dong Bang Docker & Docker Compose
cls
echo =========================================================================
echo    OISM - KHOI DONG HE THONG BANG DOCKER & DOCKER COMPOSE
echo    (Bao gom: SQL Server 2022 + Backend .NET 8 + Nginx Web App)
echo =========================================================================
echo.

docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [LOI] May tinh cua ban chua cai dat Docker hoac Docker Desktop chua chay!
    echo Vui long mo Docker Desktop va thu lai.
    echo.
    pause
    exit /b
)

echo [1/3] Dang build va khoi dong cac container trong background...
docker compose up -d --build

echo.
echo [2/3] Dang cho SQL Server 2022 va Seeder khoi tao Database OISM (khoang 15s)...
timeout /t 15 /nobreak >nul

echo.
echo [3/3] Kiem tra trang thai cac Container:
docker compose ps

echo.
echo =========================================================================
echo    HE THONG OISM DOCKER DA SAN SANG!
echo    - Frontend Web App:     http://localhost:8080
echo    - Backend API Swagger:  http://localhost:5000/api/health
echo    - SQL Server 2022 Port: localhost:1433 (User: sa / Pass: Oism2026@StrongPassword!)
echo =========================================================================
echo.
echo Dang mo Web App tren trinh duyet...
start http://localhost:8080
echo.
pause
