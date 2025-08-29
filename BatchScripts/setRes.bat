:: 
:: Switching from iGPU to dGPU mode doesn't take into account the refresh rate
:: and other display settings (Windows 11 twirks), so I have decided to automate the process.
::
:: This is triggered on power plan change, and at logon.
::

@echo off
setlocal
set "LOG=%~dp0set-display.log"

echo [%date% %time%] Start >> "%LOG%"

timeout /t 10 /nobreak >nul

:: LogPixels = 144 (0x90)
reg query "HKCU\Control Panel\Desktop" /v LogPixels 2>nul | findstr /i "0x90" >nul
if errorlevel 1 (
  echo [%date% %time%] Setting LogPixels=144 >> "%LOG%"
  reg add "HKCU\Control Panel\Desktop" /v LogPixels /t REG_DWORD /d 144 /f >> "%LOG%" 2>&1
) else (
  echo [%date% %time%] LogPixels already 144 >> "%LOG%"
)

:: Win8DpiScaling = 1 (0x1)
reg query "HKCU\Control Panel\Desktop" /v Win8DpiScaling 2>nul | findstr /i "0x1" >nul
if errorlevel 1 (
  echo [%date% %time%] Setting Win8DpiScaling=1 >> "%LOG%"
  reg add "HKCU\Control Panel\Desktop" /v Win8DpiScaling /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
) else (
  echo [%date% %time%] Win8DpiScaling already 1 >> "%LOG%"
)

:: run nircmd (in PATH)
nircmd.exe setdisplay 2560 1600 32 240 -updatereg >> "%LOG%" 2>&1

if errorlevel 1 (
  echo [%date% %time%] nircmd failed >> "%LOG%"
) else (
  echo [%date% %time%] nircmd success >> "%LOG%"
)

endlocal
exit /b 0