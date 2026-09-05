@echo off
REM ------------------------------------------------------------------
REM  KEEP THIS FILE: pure ASCII + CRLF line endings.
REM  Chinese comments or LF endings will break cmd.exe parsing
REM  (symptoms: "'exist' is not recognized", garbled codepage chars).
REM ------------------------------------------------------------------
setlocal
set "GITBASH=C:/Program Files/Git/bin/bash.exe"
set "ROOT_DIR=%~dp0.."
if not exist "%GITBASH%" goto nogit
echo Starting QuVideo ...
echo.
"%GITBASH%" "%ROOT_DIR%/scripts/dev-start.sh"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" goto failed
echo [OK] Open in browser: http://localhost:15173
goto done
:failed
echo [FAIL] Exit code %RC% -- check output above or logs directory.
goto done
:nogit
echo [ERROR] Git Bash not found: %GITBASH%
echo         Install Git for Windows, or edit GITBASH in this file.
:done
pause
endlocal
