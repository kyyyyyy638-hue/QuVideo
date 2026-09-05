@echo off
REM ------------------------------------------------------------------
REM  KEEP THIS FILE: pure ASCII + CRLF line endings.
REM  Chinese comments or LF endings break cmd.exe parsing.
REM ------------------------------------------------------------------
REM  Double-click        -> follow backend + client logs
REM  dev-logs.cmd error  -> only ERROR / WARN lines
REM  dev-logs.cmd backend / client -> single log
REM ------------------------------------------------------------------
setlocal
set "GITBASH=C:/Program Files/Git/bin/bash.exe"
set "ROOT_DIR=%~dp0.."
if not exist "%GITBASH%" goto nogit
title QuVideo Logs
"%GITBASH%" "%ROOT_DIR%/scripts/dev-logs.sh" %*
echo.
echo [log stream ended]
pause
goto :eof
:nogit
echo [ERROR] Git Bash not found: %GITBASH%
echo         Install Git for Windows, or edit GITBASH in this file.
pause
