@echo off
chcp 65001 >nul
title ForeverAI - lokale Begleit-App
cd /d "%~dp0"
if not defined FOREVERAI_GAME_DIR for %%I in ("%~dp0..\..\..") do set "FOREVERAI_GAME_DIR=%%~fI"
where node >nul 2>&1
if errorlevel 1 (
  echo Node.js wurde nicht gefunden. / Node.js was not found.
  echo Installiere eine aktuelle Node.js LTS-Version von https://nodejs.org/en/download
  echo Danach dieses Fenster schliessen und START-WINDOWS.cmd erneut starten.
  echo Then close this window and start START-WINDOWS.cmd again.
  pause
  exit /b 1
)
node -e "const v=process.versions.node.split('.').map(Number); if(v[0]<22||(v[0]===22&&v[1]<16))process.exit(1)" >nul 2>&1
if errorlevel 1 (
  echo Node.js 22.16 oder neuer wird benoetigt. / Node.js 22.16 or newer required.
  echo Download: https://nodejs.org/en/download
  pause
  exit /b 1
)
echo ForeverAI startet lokal. Keine Administratorrechte erforderlich.
echo Starting locally. No administrator privileges required.
echo Dieses Fenster offen lassen. / Keep this window open.
node server.mjs
echo.
echo Begleit-App beendet. / Companion stopped.
pause
