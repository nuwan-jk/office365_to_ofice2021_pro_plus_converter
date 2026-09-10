@echo off
setlocal EnableDelayedExpansion

pushd "%CD%"
CD /D "%~dp0"

title Office 2021 LTSC Key-Ready Setup (Fixed)
color 0B
echo ==================================================
echo    OFFICE 2021 LTSC - CUSTOMER KEY ACTIVATION SETUP
echo ==================================================
echo.

:: [1] STOP SERVICES & APPS
echo [*] Step 1: Stopping Office ClickToRun and Apps...
net stop OSPPSVC >nul 2>&1
net stop ClickToRunSvc >nul 2>&1
for %%a in (winword excel powerpnt outlook OfficeClickToRun) do (
    taskkill /F /IM %%a.exe /T >nul 2>&1
)

:: [2] DETECT OFFICE & GUID
echo [*] Step 2: Detecting Office Installation & PackageGUID...
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

:: [3] WIPE OLD LICENSES VIA REGISTRY
echo [*] Step 3: Purging old Office licenses and cache...
reg delete "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Registration" /f >nul 2>&1

:: [4] START C2R SERVICE
net start ClickToRunSvc >nul 2>&1

:: [5] FORCE CONVERSION TO LTSC PRO PLUS 2021
echo [*] Step 4: Forcing LTSC 2021 Volume Conversion & Licenses...
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

:: [6] DEPLOY OHOOK ENGINE SILENTLY
echo [*] Step 5: Deploying Ohook Hook Engine...
set "arch=x64"
if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    reg query "HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0" /v "Identifier" 2>nul | find /i "x86" >nul
    if errorlevel 1 set "arch=x64"
)
if exist "%ProgramFiles(x86)%\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe" set "arch=x86"

if "%arch%"=="x64" (
    set "C2RPath=%ProgramFiles%\Common Files\Microsoft Shared\ClickToRun"
) else (
    set "C2RPath=%ProgramFiles(x86)%\Common Files\Microsoft Shared\ClickToRun"
)

if not exist "%C2RPath%" set "C2RPath=%ProgramFiles%\Common Files\Microsoft Shared\ClickToRun"

powershell -NoProfile -Command ^
"$url = 'https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/main/MAS/All-In-Version/Files/Ohook/%arch%/sppc.dll';" ^
"try { Invoke-WebRequest -Uri $url -OutFile '%C2RPath%\sppc.dll' -UseBasicParsing } catch {}" >nul 2>&1

:: [7] STRIP PRODUCT KEY TO LEAVE IT IN "ACTIVATION REQUIRED" STATE FOR CUSTOMER
echo [*] Step 6: Stripping key so customer can input theirs...
cscript //nologo "%OSPP%" /unpkey:6F7TH >nul 2>&1
cscript //nologo "%OSPP%" /unpkey:WFG99 >nul 2>&1

:: [8] APPLYING OFFICE POLICY TWEAKS
echo [*] Step 7: Applying Office Policy Tweaks...
reg add "HKCU\Software\Microsoft\Office\16.0\Common\SignIn" /v SignInOptions /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /v UseOnlineContent /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\office\16.0\common\licensing" /v SubscriptionValidationToggle /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v SharedComputerLicensing /t REG_SZ /d "0" /f >nul 2>&1

reg add "HKCU\Software\Microsoft\Office\16.0\Common" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v SendTelemetry /t REG_DWORD /d 0 /f >nul 2>&1

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin" /v BlockAADWorkplaceJoin /t REG_DWORD /d 1 /f >nul 2>&1

color 0A
echo.
echo ==================================================
echo    [SUCCESS] READY FOR CUSTOMER KEY INPUT
echo ==================================================
echo Office is converted to LTSC 2021 with Ohook ready.
echo Opening Microsoft Word...
timeout /t 3 >nul

if exist "%_InstallRoot%\Office16\WINWORD.EXE" (
    start "" "%_InstallRoot%\Office16\WINWORD.EXE"
) else (
    start winword
)
exit
