@echo off
setlocal EnableDelayedExpansion

:: Auto-elevate silently
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -WindowStyle Hidden -Command "Start-Process '%~f0' -Verb RunAs -WindowStyle Hidden"
    exit /b
)

title Office 2021 LTSC Converter
color 0B
echo ==================================================
echo    OFFICE 2021 LTSC CONVERTER
echo ==================================================
echo.

:: [1] STOP OFFICE
echo [*] Stopping Office...
net stop OSPPSVC >nul 2>&1
net stop ClickToRunSvc >nul 2>&1
for %%a in (winword excel powerpnt outlook lync OfficeClickToRun) do (
    taskkill /F /IM %%a.exe /T >nul 2>&1
)

:: [2] FIND OFFICE PATH
echo [*] Finding Office...
set "_R="
set "_GUID="
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun" /v InstallPath 2^>nul') do set "_R=%%b\root"
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun" /v PackageGUID 2^>nul') do set "_GUID=%%b"
if "%_R%"=="" (
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun" /v InstallPath 2^>nul') do set "_R=%%b\root"
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun" /v PackageGUID 2^>nul') do set "_GUID=%%b"
)
if "%_R%"=="" (color 0C & echo [FATAL] Office not found! & pause & exit)

set "OSPP=%_R%\Office16\OSPP.VBS"
set "Lic=%_R%\Licenses16"
set "Itg=%_R%\integration\integrator.exe"
if not exist "%OSPP%" (color 0C & echo [FATAL] OSPP.VBS missing! & pause & exit)

:: [3] CLEAR OLD LICENSES
echo [*] Clearing old licenses...
reg delete "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Registration" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Roaming\Identities" /f >nul 2>&1

:: [4] START C2R
net start ClickToRunSvc >nul 2>&1

:: [5] CONVERT TO LTSC 2021
echo [*] Converting to LTSC 2021 Pro Plus...
if not "%_GUID%"=="" if exist "%Itg%" (
    "%Itg%" /I /License PRIDName=ProPlus2021Volume.16 PackageGUID="%_GUID%" PackageRoot="%_R%" >nul 2>&1
)
for /f "delims=" %%x in ('dir /b "%Lic%\client-issuance*.xrm-ms" 2^>nul') do cscript //nologo "%OSPP%" /inslic:"%Lic%\%%x" >nul 2>&1
for /f "delims=" %%x in ('dir /b "%Lic%\ProPlus2021*.xrm-ms" 2^>nul') do cscript //nologo "%OSPP%" /inslic:"%Lic%\%%x" >nul 2>&1

:: ============================================================
:: [6] INSTALL - SILENT
:: VBScript window=0 = completely invisible
:: ============================================================
echo [*] Installing Ohook hook (silent)...

set "_vbs=%TEMP%\_oh.vbs"
(
echo Dim oSh,oFS,sT,sSc,sD,sR
echo Set oSh=CreateObject("WScript.Shell"^)
echo Set oFS=CreateObject("Scripting.FileSystemObject"^)
echo sT=oSh.ExpandEnvironmentStrings("%TEMP%"^)
echo sSc=sT ^& "\_ohook.cmd"
echo sD="powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -Command " ^& Chr(34^) ^& "$ErrorActionPreference='SilentlyContinue';[Net.ServicePointManager]::SecurityProtocol=3072;(New-Object Net.WebClient^).DownloadFile('https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/master/MAS/Separate-Files-Version/Activators/Ohook_Activation_AIO.cmd','" ^& sSc ^& "')" ^& Chr(34^)
echo oSh.Run sD,0,True
echo If oFS.FileExists(sSc^) Then
echo oSh.Run "cmd.exe /c """ ^& sSc ^& """ /Ohook",0,True
echo oFS.DeleteFile sSc,True
echo End If
) > "%_vbs%"
wscript //nologo "%_vbs%" >nul 2>&1
del "%_vbs%" >nul 2>&1

:: Wait for Ohook to finish
timeout /t 10 >nul

:: ============================================================
:: [7] SET LTSC LICENSE TYPE + REMOVE KEY
:: - /inpkey  : registers LTSC 2021 Pro Plus license TYPE in system
:: - /remhst  : no KMS server (no auto KMS contact)
:: - /unpkey  : removes the key → Office shows "Not activated"
::              → customer enters key → Ohook catches → ACTIVATED ✅
:: ============================================================
echo [*] Setting up for customer activation...
cscript //nologo "%OSPP%" /inpkey:FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH >nul 2>&1
cscript //nologo "%OSPP%" /remhst >nul 2>&1
cscript //nologo "%OSPP%" /unpkey:FXYTK >nul 2>&1

:: [8] BLOCK 365 ACCOUNT OVERRIDE
echo [*] Blocking 365 license override...
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /v EnableADAL /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /v DisableADALatopWAMOverride /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Licensing" /v SubscriptionValidationToggle /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v SharedComputerLicensing /t REG_SZ /d "0" /f >nul 2>&1

:: [9] SUPPRESS NOTIFICATION BARS
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /v SubscriptionLicenseNotification /t REG_DWORD /d 0 /f >nul 2>&1
for %%a in (Word Excel PowerPoint Outlook) do (
    reg add "HKCU\Software\Microsoft\Office\16.0\%%a\Options" /v OfficeLicNotifyTime /t REG_DWORD /d 0 /f >nul 2>&1
)

:: [10] OTHER TWEAKS
reg add "HKCU\Software\Microsoft\Office\16.0\Common\SignIn" /v SignInOptions /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /v UseOnlineContent /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v SendTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin" /v BlockAADWorkplaceJoin /t REG_DWORD /d 1 /f >nul 2>&1

:: [11] OPEN WORD
color 0A
echo.
echo ==================================================
echo    [DONE] Open Word, enter key:
echo ==================================================
timeout /t 2 >nul
if exist "%_R%\Office16\WINWORD.EXE" (
    start "" "%_R%\Office16\WINWORD.EXE"
) else (
    start winword
)
exit
