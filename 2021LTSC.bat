@echo off
setlocal EnableDelayedExpansion

pushd "%CD%"
CD /D "%~dp0"

title Office 2021 LTSC Enterprise Setup
color 0B
echo ==================================================
echo    OFFICE 2021 LTSC - AUTO SETUP & ACTIVATION
echo ==================================================
echo.

:: [1] ADMIN PRIVILEGES CHECK & ELEVATION
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [*] Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit
)

:: [2] STOP SERVICES & APPS
echo [*] Step 1: Stopping Office ClickToRun and Apps...
net stop OSPPSVC >nul 2>&1
net stop ClickToRunSvc >nul 2>&1
for %%a in (winword excel powerpnt outlook OfficeClickToRun) do (
    taskkill /F /IM %%a.exe /T >nul 2>&1
)

:: [3] DETECT OFFICE & GUID
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

:: [4] WIPE OLD LICENSES VIA REGISTRY
echo [*] Step 3: Purging old Office licenses and cache...
reg delete "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Registration" /f >nul 2>&1

:: [5] START C2R SERVICE
net start ClickToRunSvc >nul 2>&1

:: [6] FORCE CONVERSION TO LTSC PRO PLUS 2021
echo [*] Step 4: Forcing LTSC 2021 Volume Conversion...
if not "%_GUID%"=="" (
    if exist "%Integrator%" (
        setlocal DisableDelayedExpansion
        "%Integrator%" /I /License PRIDName=ProPlus2021Volume.16 PackageGUID="%_GUID%" PackageRoot="%_InstallRoot%" >nul 2>&1
        endlocal
    )
)

for /f "delims=" %%x in ('dir /b "%LicensesPath%\client-issuance*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)
for /f "delims=" %%x in ('dir /b "%LicensesPath%\ProPlus2021*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)

:: [7] EMBEDDED POWERSHELL OHOOK DEPLOYMENT & ACTIVATION
echo [*] Step 5: Applying Permanent Activation Engine...
powershell -NoProfile -Command ^
"$arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' };" ^
"$C2RPath = if (Test-Path \"$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\") { \"$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\" } else { \"${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\" };" ^
"$url = \"https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/main/MAS/All-In-Version/Files/Ohook/$arch/sppc.dll\";" ^
"try { Invoke-WebRequest -Uri $url -OutFile \"$C2RPath\sppc.dll\" -UseBasicParsing } catch {}" >nul 2>&1

:: [8] SET DEFAULT GVLK KEY FOR IMMEDIATE ACTIVE STATE
echo [*] Step 6: Setting Volume Activation Key...
cscript //nologo "%OSPP%" /inpkey:FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH >nul 2>&1

:: [9] APPLYING OFFICE POLICY TWEAKS
echo [*] Step 7: Applying Office Policy Tweaks...
reg add "HKCU\Software\Microsoft\Office\16.0\Common\SignIn" /v SignInOptions /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /v UseOnlineContent /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\office\16.0\common\licensing" /v SubscriptionValidationToggle /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v SharedComputerLicensing /t REG_SZ /d "0" /f >nul 2>&1

color 0A
echo.
echo ==================================================
echo    [SUCCESS] OFFICE IS FULLY ACTIVATED
echo ==================================================
echo Opening Microsoft Word...
timeout /t 3 >nul

if exist "%_InstallRoot%\Office16\WINWORD.EXE" (
    start "" "%_InstallRoot%\Office16\WINWORD.EXE"
) else (
    start winword
)
exit
