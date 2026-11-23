@echo off
title OISM - Omnichannel Inventory and Sales Management System
cls
echo =========================================================================
echo    OISM - HE THONG QUAN LY BAN HANG VA TON KHO DA KENH (SQL SERVER 2022)
echo =========================================================================
echo.
echo  Chon che do khoi chay:
echo.
echo   [1] Khoi dong Backend .NET 8 (Ket noi truc tiep vao SQL Server 2022 tren SSMS)
echo       va tu dong mo giao dien Web App tren trinh duyet.
echo.
echo   [2] Chi mo giao dien Web App (Che do mo phong In-Memory doc lap).
echo.
echo =========================================================================
set /p opt="Nhap lua chon [1 hoac 2, mac dinh 1]: "
if "%opt%"=="" set opt=1

if "%opt%"=="1" (
    echo.
    echo Dang khoi dong Backend .NET 8 Web API tai http://localhost:5000 ...
    start "OISM Backend .NET API" cmd /k "cd /d %~dp0backend && dotnet run --urls=http://localhost:5000"
    timeout /t 3 /nobreak >nul
    echo Dang mo Web App tren trinh duyet...
    start "" "%~dp0frontend\index.html"
    echo.
    echo Backend da san sang! Moi thao tac tren Web se ghi thang vao SSMS 2022.
) else (
    echo.
    echo Dang mo Web App o che do mo phong doc lap...
    start "" "%~dp0frontend\index.html"
)

echo.
pause
