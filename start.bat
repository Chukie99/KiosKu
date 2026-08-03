@echo off
chcp 65001 >nul
title KiosKu - Server Toko
cd /d "%~dp0backend"
echo ============================================
echo   KiosKu - Server Lokal Toko
echo   Dashboard : http://localhost:8000/dashboard
echo   API Docs  : http://localhost:8000/docs
echo   Tekan CTRL+C untuk menghentikan server
echo ============================================
echo.
python -m pip install -r requirements.txt --quiet
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
pause
