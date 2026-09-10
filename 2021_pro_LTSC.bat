@echo off
setlocal EnableDelayedExpansion

:: [1] DIRECT ADMIN CHECK (NO RECURSIVE LOOPS)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ==================================================
    echo [ERROR] Please right-click the bat file and select:
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
echo    OFFICE 2021 LTSC FORCE CONVERTER (FINAL FIX)
echo ==================================================
echo.

:: [2] FORCE CLOSE OFFICE AND C2R SERVICES
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

:: [4] WIPE ALL LICENSES & REGISTRY CACHE
echo [*] Step 3: Purging old Office 365 / Retail licenses...
reg delete "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Registration" /f >nul 2>&1

cscript //nologo "%OSPP%" /remhst >nul 2>&1
cscript //nologo "%OSPP%" /ckms-domain >nul 2>&1
for /f "tokens=8" %%a in ('cscript //nologo "%OSPP%" /dstatus ^| findstr /i "Last 5"') do (
    cscript //nologo "%OSPP%" /unpkey:%%a >nul 2>&1
)

:: [5] START C2R SERVICE TO APPLY CHANGES
net start ClickToRunSvc >nul 2>&1

:: [6] FORCE CONVERSION TO 2021 LTSC PRO PLUS
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

:: [7] SET KMS SERVER & REMOVE KEY FOR MANUAL STATE
echo [*] Step 5: Configuring KMS Server and preparing manual state...
cscript //nologo "%OSPP%" /sethst:kms8.msguides.com >nul 2>&1
cscript //nologo "%OSPP%" /setprt:1688 >nul 2>&1

for /f "tokens=8" %%a in ('cscript //nologo "%OSPP%" /dstatus ^| findstr /i "Last 5"') do (
    cscript //nologo "%OSPP%" /unpkey:%%a >nul 2>&1
)

:: [8] LAUNCH WORD
color 0A
echo.
echo ==================================================
echo    [SUCCESS] READY FOR MANUAL ACTIVATION
echo ==================================================
echo Opening Microsoft Word...
timeout /t 3 >nul

if exist "%_InstallRoot%\Office16\WINWORD.EXE" (
    start "" "%_InstallRoot%\Office16\WINWORD.EXE"
) else (
    start winword
)
exit
