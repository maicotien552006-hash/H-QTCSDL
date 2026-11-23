@echo off
title OISM - Day Toan Bo Code Len GitHub Repository
cls

set GIT_CMD=git
git --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    if exist "C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Git\cmd\git.exe" (
        set GIT_CMD="C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Git\cmd\git.exe"
    ) else (
        echo [LOI] Khong tim thay Git tren may tinh!
        echo Vui long cai dat Git tu https://git-scm.com/
        pause
        exit /b
    )
)

echo =========================================================================
echo    OISM - DONG BO VA PUSH CODE LEN GITHUB REPOSITORY
echo    Repository: https://github.com/maicotien552006-hash/H-QTCSDL.git
echo =========================================================================
echo.

REM 0. Khoi tao Git neu chua co repository
if not exist ".git" (
    echo [THONG BAO] Khoi tao Git Repository moi...
    %GIT_CMD% init -b main
)

REM Cau hinh User identity neu chua thiet lap
%GIT_CMD% config user.name >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    %GIT_CMD% config user.name "maicotien552006-hash"
    %GIT_CMD% config user.email "maicotien552006@users.noreply.github.com"
)

REM 1. Chuyen sang nhanh main
%GIT_CMD% branch -M main

REM 2. Dam bao Remote Origin chinh xac
%GIT_CMD% remote remove origin >nul 2>&1
%GIT_CMD% remote add origin https://github.com/maicotien552006-hash/H-QTCSDL.git

REM 3. Stage va Commit toan bo ma nguon neu co thay doi moi
%GIT_CMD% add -A
%GIT_CMD% commit -m "feat: complete OISM data structure, schema optimization, 2-step transfer, spatial GIS, and comprehensive documentation"

echo.
echo =========================================================================
echo    CHON PHUONG THUC PUSH LEN GITHUB:
echo =========================================================================
echo.
echo   [1] GHI DE TOAN BO (Force Push - Khuyen dung)
echo       Khac phuc triet de loi '[rejected] (fetch first)' do GitHub co san file cu.
echo       Dua toan bo he thong OISM nay len lam ban chuan tren GitHub.
echo.
echo   [2] KEO CODE CU VE VA GOP (Pull Rebase roi Push)
echo       Dung neu muon giu lai cac file cu tren GitHub va gop voi he thong moi.
echo.
echo   [3] Push thong thuong (Normal Push)
echo.
echo =========================================================================
set /p opt="Nhap lua chon [1, 2 hoac 3, mac dinh 1]: "

if "%opt%"=="" set opt=1
if "%opt%"=="1" goto do_force
if "%opt%"=="2" goto do_rebase
if "%opt%"=="3" goto do_normal

:do_force
echo.
echo [DANG PUSH] Dang ghi de toan bo ma nguon he thong len GitHub (Force Push)...
%GIT_CMD% push -u origin main --force
goto finish

:do_rebase
echo.
echo [DANG REBASE] Dang keo code cu tu GitHub ve...
%GIT_CMD% pull origin main --rebase
echo [DANG PUSH] Dang day code len GitHub...
%GIT_CMD% push -u origin main
goto finish

:do_normal
echo.
echo [DANG PUSH] Dang day code len GitHub...
%GIT_CMD% push -u origin main
goto finish

:finish
echo.
if %ERRORLEVEL% EQU 0 (
    echo =========================================================================
    echo    CHUC MUNG! DA PUSH CODE LEN GITHUB THANH CONG 100%!
    echo    Xem tai: https://github.com/maicotien552006-hash/H-QTCSDL
    echo =========================================================================
) else (
    echo =========================================================================
    echo    CO THONG BAO HOAC LOI. Vui long kiem tra noi dung phia tren.
    echo =========================================================================
)
echo.
pause
