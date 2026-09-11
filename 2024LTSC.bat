@echo off
setlocal EnableDelayedExpansion

:: Auto-elevate
net session >nul 2>&1 || (powershell -WindowStyle Hidden -Command "Start-Process '%~f0' -Verb RunAs" & exit /b)

:: Find Office path (32 or 64 bit auto-detect)
set R=
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun" /v InstallPath 2^>nul') do set R=%%b\root
if not defined R for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun" /v InstallPath 2^>nul') do set R=%%b\root
if not defined R exit /b

for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun" /v PackageGUID 2^>nul') do set G=%%b
if not defined G for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun" /v PackageGUID 2^>nul') do set G=%%b

set O=%R%\Office16\OSPP.VBS
set L=%R%\Licenses16
set I=%R%\integration\integrator.exe
if not exist "%O%" exit /b

:: Kill Office processes
for %%x in (winword excel powerpnt outlook lync OfficeClickToRun) do taskkill /f /im %%x.exe >nul 2>&1
net stop ClickToRunSvc >nul 2>&1 & net stop OSPPSVC >nul 2>&1

:: Wipe old license registry (NOT account tokens - user stays signed in)
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Registration" /f >nul 2>&1

:: Remove non-2024 license files
for /f "delims=" %%f in ('dir /b "%L%\*.xrm-ms" 2^>nul') do (
    set k=0
    echo %%f | findstr /i "client-issuance ProPlus2024 Standard2024" >nul && set k=1
    if !k!==0 del "%L%\%%f" >nul 2>&1
)

net start ClickToRunSvc >nul 2>&1

:: Convert to Office LTSC 2024 Pro Plus
if defined G if exist "%I%" "%I%" /I /License PRIDName=ProPlus2024Volume.16_2024 PackageGUID="%G%" PackageRoot="%R%" >nul 2>&1
for /f "delims=" %%x in ('dir /b "%L%\client-issuance*.xrm-ms" 2^>nul') do cscript //nologo "%O%" /inslic:"%L%\%%x" >nul 2>&1
for /f "delims=" %%x in ('dir /b "%L%\ProPlus2024*.xrm-ms" 2^>nul') do cscript //nologo "%O%" /inslic:"%L%\%%x" >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds /t REG_SZ /d "ProPlus2024Volume.16_2024" /f >nul 2>&1

:: Install Ohook silently (zero windows - VBScript wrapper)
set V=%TEMP%\_oh.vbs & set C=%TEMP%\_oh.cmd
(echo Dim s,f:Set s=CreateObject("WScript.Shell"^):Set f=CreateObject("Scripting.FileSystemObject"^)
echo s.Run "powershell -NoP -NonI -W Hidden -Ex Bypass -c ""[Net.ServicePointManager]::SecurityProtocol=3072;(New-Object Net.WebClient^).DownloadFile('https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/master/MAS/Separate-Files-Version/Activators/Ohook_Activation_AIO.cmd','%C%')""",0,True
echo If f.FileExists("%C%"^) Then s.Run "cmd /c ""%C%"" /Ohook",0,True)>"%V%"
wscript //nologo "%V%" >nul 2>&1
del "%V%" "%C%" >nul 2>&1
timeout /t 10 >nul

:: Set GVLK key + KMS server (do NOT run /act - user activates via wizard)
:: KMS gives full "Getting things ready" wizard animation
:: Ohook is permanent fallback if KMS unavailable
cscript //nologo "%O%" /inpkey:XJ2XN-FW8RK-P4HMP-DKDBV-GCVGB >nul 2>&1
cscript //nologo "%O%" /sethst:kms8.msguides.com >nul 2>&1
cscript //nologo "%O%" /setprt:1688 >nul 2>&1

:: Account isolation - login works (OneDrive etc), account CANNOT affect activation
reg add "HKLM\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Licensing" /v SubscriptionValidationToggle /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /v EnableADAL /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /v DisableADALatopWAMOverride /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v SharedComputerLicensing /t REG_SZ /d "0" /f >nul 2>&1

:: Suppress notification bars
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /v SubscriptionLicenseNotification /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common" /v DiagnosticDataType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Privacy\Settings" /v SendTelemetry /t REG_DWORD /d 0 /f >nul 2>&1

start "" "%R%\Office16\WINWORD.EXE"
exit
