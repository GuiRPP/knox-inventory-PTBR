@echo off
rem Double click: updates the Workshop page's preview through SteamCMD (see upload_page.ps1).
rem Asks for the Steam login here; the password and the Steam Guard code are asked by SteamCMD itself.
set /p KNOXLOGIN=Steam login:
powershell -ExecutionPolicy Bypass -File "%~dp0upload_page.ps1" -Login %KNOXLOGIN% %*
echo.
pause
