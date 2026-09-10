@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: Auto-elevate silently (no visible UAC window flash)
:: ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -WindowStyle Hidden -Command "Start-Process '%~f0' -Verb RunAs -WindowStyle Hidden"
    exit /b
)

title Office 2021 LTSC Converter
color 0B
echo ==================================================
echo    OFFICE 2021 LTSC STABLE CONVERTER v3
echo ==================================================
echo.

:: [1] STOP SERVICES & APPS
echo [*] Step 1: Stopping Office services...
net stop OSPPSVC >nul 2>&1
net stop ClickToRunSvc >nul 2>&1
for %%a in (winword excel powerpnt outlook lync OfficeClickToRun) do (
    taskkill /F /IM %%a.exe /T >nul 2>&1
)

:: [2] DETECT OFFICE & GUID
echo [*] Step 2: Detecting Office installation...
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
    echo [FATAL] Microsoft Office C2R is not installed!
    pause
    exit
)

set "OSPP=%_InstallRoot%\Office16\OSPP.VBS"
set "LicensesPath=%_InstallRoot%\Licenses16"
set "Integrator=%_InstallRoot%\integration\integrator.exe"

if not exist "%OSPP%" (
    color 0C
    echo [FATAL] OSPP.VBS is missing!
    pause
    exit
)

:: [3] PURGE OLD LICENSES & ACCOUNT CACHE
echo [*] Step 3: Purging old licenses...
reg delete "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Registration" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Roaming\Identities" /f >nul 2>&1

:: [4] START C2R SERVICE
net start ClickToRunSvc >nul 2>&1

:: [5] FORCE CONVERSION TO LTSC PRO PLUS 2021
echo [*] Step 4: Converting to LTSC 2021 Pro Plus...
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

:: ============================================================
:: [6] INSTALL OHOOK - COMPLETELY SILENT (zero visible windows)
:: ============================================================
:: Strategy: VBScript with window=0 launches hidden PowerShell
:: PowerShell downloads ONLY the Ohook script (not full MAS menu)
:: Passes /Ohook parameter for silent non-interactive install
:: ============================================================
echo [*] Step 5: Installing Ohook activation hook (silent)...

set "vbs_path=%TEMP%\_ohook_silent.vbs"
(
    echo Dim oShell, oFSO, sTemp, sScript, sCmd
    echo Set oShell = CreateObject("WScript.Shell"^)
    echo Set oFSO = CreateObject("Scripting.FileSystemObject"^)
    echo sTemp = oShell.ExpandEnvironmentStrings("%TEMP%"^)
    echo sScript = sTemp ^& "\_ohook_inst.cmd"
    echo.
    echo ' Download ONLY the Ohook script (not the full MAS menu launcher^)
    echo sCmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -Command " ^& Chr(34^)
    echo sCmd = sCmd ^& "$ErrorActionPreference='SilentlyContinue';"
    echo sCmd = sCmd ^& "try{"
    echo sCmd = sCmd ^& "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;"
    echo sCmd = sCmd ^& "$wc=New-Object Net.WebClient;"
    echo sCmd = sCmd ^& "$url='https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/master/MAS/Separate-Files-Version/Activators/Ohook_Activation_AIO.cmd';"
    echo sCmd = sCmd ^& "$p='" ^& sScript ^& "';"
    echo sCmd = sCmd ^& "$wc.DownloadFile($url,$p);"
    echo sCmd = sCmd ^& "}catch{}"
    echo sCmd = sCmd ^& Chr(34^)
    echo ' Download the script with window=0
    echo oShell.Run sCmd, 0, True
    echo.
    echo ' Now run the Ohook script with /Ohook parameter (silent, no menu^)
    echo If oFSO.FileExists(sScript^) Then
    echo     oShell.Run "cmd.exe /c """ ^& sScript ^& """ /Ohook", 0, True
    echo     oFSO.DeleteFile sScript, True
    echo End If
) > "%vbs_path%"

wscript //nologo "%vbs_path%"
del "%vbs_path%" >nul 2>&1

:: Wait for Ohook to complete installation
timeout /t 5 >nul

:: ============================================================
:: [7] VERIFY OHOOK - Check if sppc.dll was patched
:: ============================================================
set "OhookOK=0"

:: Check if Ohook registration exists in registry
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" /v OhookVersion >nul 2>&1
if %errorlevel%==0 set "OhookOK=1"

:: Also check if the Ohook DLL is present in System32
if exist "%SystemRoot%\System32\sppc.dll" (
    :: Check file size - Ohook DLL is much smaller than original Microsoft sppc.dll
    for %%f in ("%SystemRoot%\System32\sppc.dll") do (
        if %%~zf LSS 100000 set "OhookOK=1"
    )
)

echo [*] Ohook status: !OhookOK!

:: ============================================================
:: [8] KEY SETUP - Based on Ohook status
:: ============================================================

if "!OhookOK!"=="1" (
    :: ---- OHOOK INSTALLED: Set key then REMOVE it ----
    :: Customer will enter key in activation wizard → Ohook activates instantly
    echo [*] Step 6: Ohook ready - Setting up key for customer activation...
    
    :: Install key (sets up LTSC license type in registry)
    cscript //nologo "%OSPP%" /inpkey:FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH >nul 2>&1
    
    :: Remove KMS server settings (no auto-KMS activation)
    cscript //nologo "%OSPP%" /remhst >nul 2>&1
    
    :: *** CRITICAL: Remove the key so Office shows "Not activated" ***
    :: Customer will be prompted to enter key → types FXYTK → Ohook catches → "Activated" shown
    cscript //nologo "%OSPP%" /unpkey:FXYTK >nul 2>&1
    
    echo [*] Office is ready - customer activation wizard will appear on first open.
    
) else (
    :: ---- OHOOK FAILED: Fall back to KMS activation ----
    :: Office will be activated but won't show customer activation experience
    echo [*] Step 6: Ohook not confirmed - using KMS fallback activation...
    
    cscript //nologo "%OSPP%" /inpkey:FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH >nul 2>&1
    cscript //nologo "%OSPP%" /sethst:kms8.msguides.com >nul 2>&1
    cscript //nologo "%OSPP%" /setprt:1688 >nul 2>&1
    cscript //nologo "%OSPP%" /act >nul 2>&1
    
    echo [*] KMS fallback activation applied.
)

:: [9] BLOCK CAMPUS ACCOUNT / 365 LICENSE OVERRIDE
echo [*] Step 7: Blocking 365 account license override...

:: Disable ADAL (stops 365 online license being applied over local license)
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /v EnableADAL /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /v DisableADALatopWAMOverride /t REG_DWORD /d 1 /f >nul 2>&1

:: Block subscription license validation
reg add "HKLM\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Licensing" /v SubscriptionValidationToggle /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v SharedComputerLicensing /t REG_SZ /d "0" /f >nul 2>&1

:: [10] SUPPRESS NOTIFICATION BARS (even if activation state shows warning)
echo [*] Step 8: Suppressing license notification bars...

for %%a in (Word Excel PowerPoint Outlook) do (
    reg add "HKCU\Software\Microsoft\Office\16.0\%%a\Options" /v OfficeLicNotifyTime /t REG_DWORD /d 0 /f >nul 2>&1
)
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /v SubscriptionLicenseNotification /t REG_DWORD /d 0 /f >nul 2>&1

:: [11] REMAINING POLICY TWEAKS
reg add "HKCU\Software\Microsoft\Office\16.0\Common\SignIn" /v SignInOptions /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /v UseOnlineContent /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v SendTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin" /v BlockAADWorkplaceJoin /t REG_DWORD /d 1 /f >nul 2>&1

:: [12] DONE
color 0A
echo.
echo ==================================================

if "!OhookOK!"=="1" (
    echo    [READY] Open Word - customer enters key to activate
) else (
    echo    [READY] KMS fallback - Office is activated
)

echo ==================================================
timeout /t 2 >nul

if exist "%_InstallRoot%\Office16\WINWORD.EXE" (
    start "" "%_InstallRoot%\Office16\WINWORD.EXE"
) else (
    start winword
)
exit
