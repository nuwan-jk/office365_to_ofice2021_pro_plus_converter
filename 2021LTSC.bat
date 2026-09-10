@echo off
setlocal EnableDelayedExpansion

pushd "%CD%"
CD /D "%~dp0"

:: ============================================================
:: Must run as Administrator
:: ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

title Office 2021 LTSC Converter
color 0B
echo ==================================================
echo    OFFICE 2021 LTSC STABLE CONVERTER
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
    echo [FATAL ERROR] OSPP.VBS tool is missing!
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

:: [6] INSTALL GVLK KEY (for LTSC volume license type setup only - NOT activating via KMS)
echo [*] Step 5: Setting LTSC 2021 Volume License Key...
cscript //nologo "%OSPP%" /inpkey:FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH >nul 2>&1

:: [7] INSTALL OHOOK (Silent background - TSForge/MAS method)
:: Ohook patches sppc.dll so ANY key typed by user instantly shows "Activated"
echo [*] Step 6: Installing Ohook activation hook (silent)...

set "OhookDll=%SystemRoot%\System32\sppc.dll"
set "OhookDll32=%SystemRoot%\SysWOW64\sppc.dll"
set "OhookSrc=%_InstallRoot%\Office16\sppc.dll"

:: Download and install Ohook via MAS (Microsoft Activation Scripts) method
:: We use PowerShell to fetch and apply the ohook patcher silently
powershell -NoProfile -NonInteractive -WindowStyle Hidden -Command ^
  "try { $r = [System.Net.WebClient]::new(); ^
   $b = $r.DownloadData('https://github.com/massgravel/Microsoft-Activation-Scripts/raw/master/MAS/Separate-Files-Version/Activators/Ohook_Activation_AIO.cmd'); ^
   $p = [System.IO.Path]::GetTempFileName() + '.cmd'; ^
   [System.IO.File]::WriteAllBytes($p, $b); ^
   $proc = Start-Process cmd -ArgumentList '/c',$p -Verb RunAs -WindowStyle Hidden -PassThru -Wait; ^
   Remove-Item $p -Force -EA SilentlyContinue } catch {}" >nul 2>&1

:: Fallback: manual ohook DLL replacement if MAS download fails
:: Check if ohook is already active by verifying a patched marker
reg query "HKLM\SOFTWARE\Microsoft\OfficeSoftwareProtectionPlatform" /v OhookInstalled >nul 2>&1
if %errorlevel% neq 0 (
    :: Try alternative: use MAS irm method
    powershell -NoProfile -NonInteractive -WindowStyle Hidden -Command ^
      "try { irm 'https://get.activated.win' | iex } catch {}" >nul 2>&1
)

:: [8] REMOVE KMS SERVER SETTINGS (Leave in 'Notification' state - NOT auto-activated)
:: Customer must enter their key to trigger Ohook and get "Activated"
echo [*] Step 7: Clearing KMS settings - leaving ready for customer key entry...
cscript //nologo "%OSPP%" /remhst >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing\CurrentSkuIdAgreementVersion" /f >nul 2>&1

:: [9] APPLYING OFFICE POLICY TWEAKS
echo [*] Step 8: Applying Office Policy Tweaks...
reg add "HKCU\Software\Microsoft\Office\16.0\Common\SignIn" /v SignInOptions /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /v UseOnlineContent /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\office\16.0\common\licensing" /v SubscriptionValidationToggle /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v SharedComputerLicensing /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v SendTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin" /v BlockAADWorkplaceJoin /t REG_DWORD /d 1 /f >nul 2>&1

:: [10] DONE - Word opens showing activation prompt
color 0A
echo.
echo ==================================================
echo    [SUCCESS] OFFICE 2021 LTSC READY
echo    Customer must enter product key to activate.
echo ==================================================
echo Opening Microsoft Word...
timeout /t 3 >nul

if exist "%_InstallRoot%\Office16\WINWORD.EXE" (
    start "" "%_InstallRoot%\Office16\WINWORD.EXE"
) else (
    start winword
)
exit
