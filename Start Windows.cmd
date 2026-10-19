@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if errorlevel 1 goto use_python
py -3 start.py %*
set "PCMONITOR_EXIT=%errorlevel%"
goto finished
:use_python
where python >nul 2>nul
if errorlevel 1 goto missing_python
python start.py %*
set "PCMONITOR_EXIT=%errorlevel%"
goto finished
:missing_python
echo Instala Python 3.11 o posterior con pip y vuelve a abrir este archivo.
set "PCMONITOR_EXIT=1"
:finished
pause
exit /b %PCMONITOR_EXIT%
