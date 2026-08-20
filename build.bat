@echo off
echo ========================================
echo   KiosKu Build Script
echo ========================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python tidak ditemukan! Install Python 3.10+ dulu.
    pause
    exit /b 1
)

REM Check Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js tidak ditemukan! Install Node.js dulu.
    pause
    exit /b 1
)

REM Step 1: Build Web Dashboard
echo [1/4] Building Web Dashboard...
cd web_dashboard
call npm install
call npm run build
cd ..
if errorlevel 1 (
    echo [ERROR] Gagal build web dashboard!
    pause
    exit /b 1
)
echo [OK] Web Dashboard built.
echo.

REM Step 2: Install Python dependencies
echo [2/4] Installing Python dependencies...
pip install pyinstaller -q
pip install -r backend\requirements.txt -q
echo [OK] Dependencies installed.
echo.

REM Step 3: Build EXE
echo [3/4] Building EXE...
pyinstaller kiosku.spec --clean --noconfirm
if errorlevel 1 (
    echo [ERROR] Gagal build EXE!
    pause
    exit /b 1
)
echo [OK] EXE built.
echo.

REM Step 4: Copy data folder
echo [4/4] Preparing distribution...
if not exist "dist\KiosKu\data" mkdir "dist\KiosKu\data"
if not exist "dist\KiosKu\data\backups" mkdir "dist\KiosKu\data\backups"
echo [OK] Distribution ready.
echo.

echo ========================================
echo   BUILD BERHASIL!
echo ========================================
echo   EXE: dist\KiosKu\KiosKu.exe
echo   Jalankan file exe untuk memulai.
echo ========================================
echo.
pause
