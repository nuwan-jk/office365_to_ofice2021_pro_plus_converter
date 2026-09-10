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
for %%a in (winword excel powerpnt outlook lync OfficeClickToRun msoasb) do (
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

:: ============================================================
:: [3] NUKE ALL EXISTING ACTIVATION + LICENSE DATA
:: Complete clean slate - remove EVERYTHING
:: ============================================================
echo [*] Wiping all existing license/activation data...

:: Registry wipe
reg delete "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Registration" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Roaming\Identities" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\ServicesManagerCache" /f >nul 2>&1

:: ============================================================
:: REMOVE ALL 365 / RETAIL / SUBSCRIPTION LICENSE FILES
:: Keep ONLY: client-issuance*.xrm-ms and ProPlus2021*.xrm-ms
:: This removes "Subscription Product: Microsoft 365" display
:: ============================================================
echo [*] Removing 365 and subscription license files...
if exist "%Lic%" (
    for /f "delims=" %%f in ('dir /b "%Lic%\*.xrm-ms" 2^>nul') do (
        set "_keep=0"
        echo %%f | findstr /i "client-issuance" >nul && set "_keep=1"
        echo %%f | findstr /i "ProPlus2021" >nul && set "_keep=1"
        echo %%f | findstr /i "Standard2021" >nul && set "_keep=1"
        if "!_keep!"=="0" (
            del "%Lic%\%%f" >nul 2>&1
        )
    )
)

:: Also clear SoftwareProtectionPlatform cached tokens
reg delete "HKLM\SOFTWARE\Microsoft\OfficeSoftwareProtectionPlatform" /v "BackupProductKeyDefault" /f >nul 2>&1
net start OSPPSVC >nul 2>&1

:: [4] START C2R
net start ClickToRunSvc >nul 2>&1

:: [5] CONVERT TO LTSC 2021 PRO PLUS
echo [*] Converting to LTSC 2021 Pro Plus...
if not "%_GUID%"=="" if exist "%Itg%" (
    "%Itg%" /I /License PRIDName=ProPlus2021Volume.16 PackageGUID="%_GUID%" PackageRoot="%_R%" >nul 2>&1
)

:: Install ONLY LTSC 2021 + client-issuance licenses (the ones we kept above)
for /f "delims=" %%x in ('dir /b "%Lic%\client-issuance*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%Lic%\%%x" >nul 2>&1
)
for /f "delims=" %%x in ('dir /b "%Lic%\ProPlus2021*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%Lic%\%%x" >nul 2>&1
)

:: [6] INSTALL OHOOK SILENTLY (zero visible windows)
echo [*] Installing Ohook (silent)...
set "_vbs=%TEMP%\_oh.vbs"
(
echo Dim oSh,oFS,sT,sSc,sD
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
timeout /t 10 >nul

:: [7] SET LTSC KEY THEN REMOVE IT (customer enters it to trigger Ohook)
echo [*] Setting up for customer activation...
cscript //nologo "%OSPP%" /inpkey:FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH >nul 2>&1
cscript //nologo "%OSPP%" /remhst >nul 2>&1
cscript //nologo "%OSPP%" /unpkey:FXYTK >nul 2>&1

:: ============================================================
:: [8] BLOCK ACCOUNT-BASED LICENSE OVERRIDE
:: User CAN sign in (OneDrive, SharePoint work fine)
:: But account license will NEVER override local LTSC license
:: ============================================================
echo [*] Blocking account license override...

:: Block ADAL - prevents online license check via account
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /v EnableADAL /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /v DisableADALatopWAMOverride /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /v NoDomainUser /t REG_DWORD /d 1 /f >nul 2>&1

:: Block subscription validation (most important key)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Licensing" /v SubscriptionValidationToggle /t REG_DWORD /d 0 /f >nul 2>&1

:: Force volume licensing mode only (ignores account subscription)
reg add "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v SharedComputerLicensing /t REG_SZ /d "0" /f >nul 2>&1

:: Block online license resolution
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /v OfficeLicensingEnabled /t REG_DWORD /d 1 /f >nul 2>&1

:: [9] SUPPRESS NOTIFICATION BARS
echo [*] Suppressing notification bars...
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /v SubscriptionLicenseNotification /t REG_DWORD /d 0 /f >nul 2>&1
for %%a in (Word Excel PowerPoint Outlook) do (
    reg add "HKCU\Software\Microsoft\Office\16.0\%%a\Options" /v OfficeLicNotifyTime /t REG_DWORD /d 0 /f >nul 2>&1
)

:: [10] POLICY TWEAKS
reg add "HKCU\Software\Microsoft\Office\16.0\Common\SignIn" /v SignInOptions /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /v UseOnlineContent /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v SendTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin" /v BlockAADWorkplaceJoin /t REG_DWORD /d 1 /f >nul 2>&1

:: [11] OPEN WORD
color 0A
echo.
echo ==================================================
echo    [DONE] Word is opening. Customer enters key.
echo    Key: FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH
echo ==================================================
timeout /t 2 >nul
if exist "%_R%\Office16\WINWORD.EXE" (
    start "" "%_R%\Office16\WINWORD.EXE"
) else (
    start winword
)
exit
