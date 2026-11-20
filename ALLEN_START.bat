@echo off
setlocal enabledelayedexpansion
title ALLEN AI setup
cd /d "%~dp0backend"

set PY=
py -3.12 -V >nul 2>nul && set PY=py -3.12
if not defined PY ( py -3.13 -V >nul 2>nul && set PY=py -3.13 )
if not defined PY ( python -V >nul 2>nul && set PY=python )
if not defined PY (
  echo Python pawa jayni. Install korun: https://www.python.org/downloads/
  echo Install-er por PC restart kore ei file abar chalan.
  start https://www.python.org/downloads/
  pause
  exit /b 1
)
echo Python: !PY!

if not exist .venv (
  echo [1/4] Python environment banano hocche...
  !PY! -m venv .venv
  if errorlevel 1 ( echo venv toiri hoy nai & pause & exit /b 1 )
)
call .venv\Scripts\activate.bat

echo [2/4] Package install hocche (prothom bar kichu minute lagbe)...
pip install -q -e .
if errorlevel 1 ( echo pip install fail korse. Upore error ta dekhe amake pathan. & pause & exit /b 1 )

if not exist .env (
  echo.
  echo [3/4] Setup. Free key nite: https://console.groq.com/keys
  set /p KEY=Groq API key paste korun: 
  set /p CODE=Ekta gopon code din ^(jemon allen12345^): 
  for /f %%i in ('python -c "import secrets;print(secrets.token_hex(24))"') do set SECRET=%%i
  (
    echo LLM_PROVIDER=openai_compat
    echo LLM_BASE_URL=https://api.groq.com/openai/v1
    echo LLM_API_KEY=!KEY!
    echo LLM_MODEL=openai/gpt-oss-120b
    echo SECRET_KEY=!SECRET!
    echo REGISTRATION_CODE=!CODE!
  ) > .env
  echo .env toiri hoyeche.
)

if not exist "%~dp0cloudflared.exe" (
  echo cloudflared download hocche (iPhone-er jonno)...
  curl -L -s -o "%~dp0cloudflared.exe" https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
)

echo [4/4] Chalu hocche...
start "ALLEN server" cmd /k "cd /d %~dp0backend && call .venv\Scripts\activate.bat && uvicorn app.main:app --host 0.0.0.0 --port 8000"
if exist "%~dp0cloudflared.exe" (
  start "ALLEN tunnel (iPhone link)" cmd /k ""%~dp0cloudflared.exe" tunnel --url http://localhost:8000"
)
timeout /t 5 >nul
start http://localhost:8000/app/

echo.
echo PC: http://localhost:8000/app/  (opore gear icon e gopon code din)
echo iPhone: "ALLEN tunnel" window-e https://....trycloudflare.com link pabenn. Safari-te oi link + /app/ kholen.
echo Bondho korte duto window-i close korun.
pause
