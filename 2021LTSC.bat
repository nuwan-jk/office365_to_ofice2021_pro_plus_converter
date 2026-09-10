@echo off
setlocal EnableDelayedExpansion

:: [1] SIMPLE ADMIN CHECK
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ==================================================
    echo [ERROR] Please right-click and select:
    echo "Run as administrator"
    echo ==================================================
    pause
    exit /b
)

pushd "%CD%"
CD /D "%~dp0"

title Office 2021 LTSC Force Converter
color 0B
echo ==================================================
echo    OFFICE 2021 LTSC FORCE CONVERTER (FINAL)
echo ==================================================
echo.

:: [2] STOP SERVICES & APPS
echo [*] Step 1: Stopping Office ClickToRun and Apps...
net stop OSPPSVC >nul 2>&1
net stop ClickToRunSvc >nul 2>&1
for %%a in (winword excel powerpnt outlook OfficeClickToRun) do (
    taskkill /F /IM %%a.exe /T >nul 2>&1
)

:: [3] DETECT OFFICE & GUID
echo [*] Step 2: Detecting Office Installation ^& PackageGUID...
set "_InstallRoot="
set "_GUID="
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun" /v InstallPath 2^>nul') do (set "_InstallRoot=%%b\root")
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun" /v PackageGUID 2^>nul') do (set "_GUID=%%b")

if "%_InstallRoot%"=="" (
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun" /v InstallPath 2^>nul') do (set "_InstallRoot=%%b\root")
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun" /v PackageGUID 2^>nul') do (set "_GUID=%%b")
)
if "%_InstallRoot%"=="" (
    color 0C
    echo [FATAL ERROR] Microsoft Office C2R is not installed!
    pause
    exit
)

set "OSPP=%_InstallRoot%\Office16\OSPP.VBS"
set "LicensesPath=%_InstallRoot%\Licenses16"
set "Integrator=%_InstallRoot%\integration\integrator.exe"

if not exist "%OSPP%" (
    color 0C
    echo [FATAL ERROR] OSPP.VBS tool is missing.
    pause
    exit
)

:: [4] WIPE OLD LICENSES
echo [*] Step 3: Purging old Office 365 / Retail licenses...
reg delete "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Registration" /f >nul 2>&1

cscript //nologo "%OSPP%" /remhst >nul 2>&1
cscript //nologo "%OSPP%" /ckms-domain >nul 2>&1
for /f "tokens=8" %%a in ('cscript //nologo "%OSPP%" /dstatus ^| findstr /i "Last 5"') do (
    cscript //nologo "%OSPP%" /unpkey:%%a >nul 2>&1
)

:: [5] START C2R SERVICE
net start ClickToRunSvc >nul 2>&1

:: [6] FORCE CONVERSION TO LTSC PRO PLUS 2021
echo [*] Step 4: Forcing LTSC 2021 Volume Conversion...
if not "%_GUID%"=="" (
    if exist "%Integrator%" (
        "%Integrator%" /I /License PRIDName=ProPlus2021Volume.16 PackageGUID="%_GUID%" PackageRoot="%_InstallRoot%" >nul 2>&1
    )
)

for /f "delims=" %%x in ('dir /b "%LicensesPath%\client-issuance*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)
for /f "delims=" %%x in ('dir /b "%LicensesPath%\ProPlus2021*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)

:: [7] SET KMS & STRIP KEYS FOR MANUAL STATE
echo [*] Step 5: Configuring KMS Server and manual state...
cscript //nologo "%OSPP%" /sethst:kms8.msguides.com >nul 2>&1
cscript //nologo "%OSPP%" /setprt:1688 >nul 2>&1

for /f "tokens=8" %%a in ('cscript //nologo "%OSPP%" /dstatus ^| findstr /i "Last 5"') do (
    cscript //nologo "%OSPP%" /unpkey:%%a >nul 2>&1
)

:: [8] APPLYING NEW REGISTRY TWEAKS (Sign-in, Telemetry, Workplace Join)
echo [*] Step 6: Applying Office Policy Tweaks...
reg add "HKCU\Software\Microsoft\Office\16.0\Common\SignIn" /v SignInOptions /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /v UseOnlineContent /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\office\16.0\common\licensing" /v SubscriptionValidationToggle /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v SharedComputerLicensing /t REG_SZ /d "0" /f >nul 2>&1

reg add "HKCU\Software\Microsoft\Office\16.0\Common" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v SendTelemetry /t REG_DWORD /d 0 /f >nul 2>&1

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin" /v BlockAADWorkplaceJoin /t REG_DWORD /d 1 /f >nul 2>&1

:: [9] POP-UP PROMPT FOR RESTART (Restart Now / Cancel Buttons)
echo [*] Step 7: Prompting user for restart...
echo Set objShell = CreateObject("WScript.Shell") > "%temp%\restart_prompt.vbs"
echo intBtn = objShell.Popup("Office 2021 LTSC configuration is successfully completed! Do you want to restart your computer now to apply all settings?", 0, "Office Setup - Restart Required", 4 + 32) >> "%temp%\restart_prompt.vbs"
echo If intBtn = 6 Then >> "%temp%\restart_prompt.vbs"
echo     objShell.Run "shutdown /r /t 5", 0, False >> "%temp%\restart_prompt.vbs"
echo End If >> "%temp%\restart_prompt.vbs"

cscript //nologo "%temp%\restart_prompt.vbs" >nul 2>&1
del "%temp%\restart_prompt.vbs" >nul 2>&1

:: [10] LAUNCH WORD (If they click Cancel or close prompt)
color 0A
echo.
echo ==================================================
echo    [SUCCESS] SETUP COMPLETED
echo ==================================================
echo Opening Microsoft Word...
timeout /t 3 >nul

if exist "%_InstallRoot%\Office16\WINWORD.EXE" (
    start "" "%_InstallRoot%\Office16\WINWORD.EXE"
) else (
    start winword
)
exit