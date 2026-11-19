@echo off
title OISM - Day Toan Bo Code Len GitHub Repository
cls
echo =========================================================================
echo    OISM - DONG BO VA PUSH CODE LEN GITHUB REPOSITORY
echo    Repository: https://github.com/maicotien552006-hash/H-QTCSDL.git
echo =========================================================================
echo.

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

echo Su dung trinh Git: %GIT_CMD%
echo.

REM 1. Khoi tao Git repository neu chua co
if not exist ".git" (
    echo [1/5] Khoi tao Git repository noi bo...
    %GIT_CMD% init
) else (
    echo [1/5] Git repository da ton tai.
)

REM 2. Cau hinh Remote Origin
%GIT_CMD% remote get-url origin >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [2/5] Gan Remote Origin toi repository cua nhom...
    %GIT_CMD% remote add origin https://github.com/maicotien552006-hash/H-QTCSDL.git
) else (
    echo [2/5] Cap nhat Remote Origin...
    %GIT_CMD% remote set-url origin https://github.com/maicotien552006-hash/H-QTCSDL.git
)

REM 3. Chuyen sang nhanh main
echo [3/5] Thiet lap nhanh chinh la 'main'...
%GIT_CMD% branch -M main

REM 4. Stage toan bo tep va tao Commit
echo [4/5] Dang them toan bo ma nguon, Docker, CI/CD vao commit...
%GIT_CMD% add -A
%GIT_CMD% commit -m "feat: complete OISM system with Docker Compose, GitHub Actions CI/CD, SQL Server 2022 and modern UI"

REM 5. Push code len GitHub
echo.
echo =========================================================================
echo    [5/5] CHUAN BI PUSH LEN GITHUB:
echo    Neu trinh duyet hoac cua so Windows hien len, hay dang nhap hoac
echo    nhap Personal Access Token (PAT) cua tai khoan GitHub: maicotien552006-hash
echo =========================================================================
echo.
%GIT_CMD% push -u origin main

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo -------------------------------------------------------------------------
    echo [CANH BAO] Neu repository tren GitHub da co san file README/Commit truoc do,
    echo ban co the muon keo du lieu ve truoc hoac push de (force):
    echo.
    echo Lua chon:
    echo   [1] Thu keo code cu va rebase: git pull origin main --rebase roi push lai
    echo   [2] Ghi de toan bo (Force Push): git push -u origin main --force
    echo   [3] Thoat de kiem tra lai
    echo -------------------------------------------------------------------------
    set /p pushOpt="Nhap lua chon [1, 2 hoac 3]: "
    if "%pushOpt%"=="1" (
        %GIT_CMD% pull origin main --rebase
        %GIT_CMD% push -u origin main
    )
    if "%pushOpt%"=="2" (
        %GIT_CMD% push -u origin main --force
    )
)

echo.
echo =========================================================================
echo    HOAN TAT QUA TRINH PUSH CODE LEN GITHUB!
echo =========================================================================
pause
