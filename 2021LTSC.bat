@echo off
setlocal EnableDelayedExpansion

pushd "%CD%"
CD /D "%~dp0"

title Office Reseller Setup (Retail Edition + Ohook)
color 0B
echo ==================================================
echo   OFFICE RETAIL SETUP - PERFECT WIZARD ACTIVATION
echo ==================================================
echo.

:: [1] Office සේවාවන් නැවැත්වීම
echo [*] Step 1: Stopping Office Services...
net stop OSPPSVC >nul 2>&1
net stop ClickToRunSvc >nul 2>&1
for %%a in (winword excel powerpnt outlook OfficeClickToRun) do (
    taskkill /F /IM %%a.exe /T >nul 2>&1
)

:: [2] Office පිහිටීම සොයාගැනීම
echo [*] Step 2: Detecting Office Location...
set "_InstallRoot="
set "OfficeArch=x64"

for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun" /v InstallPath 2^>nul') do (set "_InstallRoot=%%b\root")
if "%_InstallRoot%"=="" (
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun" /v InstallPath 2^>nul') do (set "_InstallRoot=%%b\root")
    set "OfficeArch=x86"
)

if "%_InstallRoot%"=="" (
    color 0C
    echo [ERROR] Office is not installed!
    pause
    exit
)

set "OSPP=%_InstallRoot%\Office16\OSPP.VBS"
set "LicensesPath=%_InstallRoot%\Licenses16"

:: [3] පරණ ලයිසන් මකා දැමීම
echo [*] Step 3: Clearing old licenses...
reg delete "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
net start ClickToRunSvc >nul 2>&1

:: [4] RETAIL ලයිසන් එක දැමීම (මේකෙන් තමයි Activation Wizard එක හරියටම වැඩ කරන්නේ)
echo [*] Step 4: Forcing RETAIL Licenses for proper Activation UI...
for /f "delims=" %%x in ('dir /b "%LicensesPath%\client-issuance*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)
for /f "delims=" %%x in ('dir /b "%LicensesPath%\ProPlus2021Retail*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)

:: [5] දැනට තියෙන කීස් අයින් කර 'Unactivated' කිරීම
echo [*] Step 5: Stripping existing keys...
cscript //nologo "%OSPP%" /unpkey:6F7TH >nul 2>&1
cscript //nologo "%OSPP%" /unpkey:WFG99 >nul 2>&1
cscript //nologo "%OSPP%" /unpkey:PTCGD >nul 2>&1

:: [6] Ohook Engine එක හරියටම Install කිරීම (UI එක බයිපාස් කිරීමට)
echo [*] Step 6: Deploying Ohook Activation Engine...
set "C2RShared="
if exist "%ProgramFiles%\Common Files\Microsoft Shared\ClickToRun" set "C2RShared=%ProgramFiles%\Common Files\Microsoft Shared\ClickToRun"
if exist "%ProgramFiles(x86)%\Common Files\Microsoft Shared\ClickToRun" set "C2RShared=%ProgramFiles(x86)%\Common Files\Microsoft Shared\ClickToRun"
set "OfficeVFS=%_InstallRoot%\vfs\System"

powershell -NoProfile -Command ^
"$arch = '%OfficeArch%';" ^
"$url = 'https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/main/MAS/All-In-Version/Files/Ohook/' + $arch + '/sppc.dll';" ^
"try { Invoke-WebRequest -Uri $url -OutFile '%C2RShared%\sppc.dll' -UseBasicParsing; Copy-Item '%C2RShared%\sppc.dll' '%OfficeVFS%\sppc.dll' -Force; Write-Host 'Ohook deployed.' } catch {}"

:: [7] අනවශ්‍ය Popups නැවැත්වීම
echo [*] Step 7: Disabling Startup Popups...
reg add "HKCU\Software\Microsoft\Office\16.0\Common\General" /v "ShownFirstRunOptin" /t REG_DWORD /d 1 /f >nul 2>&1

color 0A
echo.
echo ==================================================
echo   [SUCCESS] SETUP DONE! READY FOR CUSTOMER KEY
echo ==================================================
echo.
timeout /t 3 >nul
start winword
exit
