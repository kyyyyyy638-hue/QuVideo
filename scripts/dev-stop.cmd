@echo off
setlocal
set "GITBASH=C:/Program Files/Git/bin/bash.exe"
set "ROOT_DIR=%~dp0.."
if not exist "%GITBASH%" goto nogit
"%GITBASH%" "%ROOT_DIR%/scripts/dev-stop.sh" %*
echo.
goto done
:nogit
echo [ERROR] Git Bash not found: %GITBASH%
:done
pause
endlocal
