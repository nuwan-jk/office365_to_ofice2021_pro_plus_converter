@echo off
setlocal EnableDelayedExpansion

:: [1] AUTO-ADMIN
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting Administrator Privileges...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B
)
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
pushd "%CD%"
CD /D "%~dp0"

title Office 2021 System Preparation Tool
color 0B
echo ==================================================
echo    OFFICE 2021 PREPARATION TOOL (V11-MOD)
echo ==================================================
echo.

:: [2] FORCE CLOSE RUNNING APPS
echo [*] Step 1: Closing running Office applications...
for %%a in (winword excel powerpnt outlook) do (
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
    echo [FATAL ERROR] OSPP.VBS tool is missing. Corrupted installation!
    pause
    exit
)

:: [4] DEEP CLEANING (OUTLOOK & IDENTITIES ARE SAFE)
echo [*] Step 3: Wiping License Cache...
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Licensing" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Registration" /f >nul 2>&1

:: [5] MITIGATE M365 AUTO-ACTIVATION
echo [*] Step 4: Applying Subscription Mitigation Policy...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Licensing" /v DisableSubscription /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Licensing" /v DisableSubscription /t REG_DWORD /d 1 /f >nul 2>&1

:: [6] PURGE GHOST KEYS
echo [*] Step 5: Destroying old Licenses and Ghost Keys...
cscript //nologo "%OSPP%" /remhst >nul 2>&1
cscript //nologo "%OSPP%" /ckms-domain >nul 2>&1
for /f "delims=" %%a in ('powershell -NoProfile -Command "(cscript //nologo \"%OSPP%\" /dstatus) | Select-String -Pattern 'Last 5 characters of installed product key: ([A-Z0-9]{5})' | ForEach-Object { $_.Matches.Groups[1].Value }" 2^>nul') do (
    cscript //nologo "%OSPP%" /unpkey:%%a >nul 2>&1
)

:: [7] VERIFY CERTIFICATES
echo [*] Step 6: Validating 2021 Pro Plus Certificates...
dir /b "%LicensesPath%\ProPlus2021*.xrm-ms" >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [FATAL ERROR] Office 2021 Certificates are missing on this system!
    pause
    exit
)

:: [8] SMART CONVERSION (VOLUME - NO KEY INJECTED)
echo [*] Step 7: Forcing Office 2021 Pro Plus Conversion...
if not "%_GUID%"=="" (
    if exist "%Integrator%" (
        "%Integrator%" /I /License PRIDName=ProPlus2021Volume.16 PackageGUID="%_GUID%" PackageRoot="%_InstallRoot%" >nul 2>&1
        if !errorlevel! neq 0 (
            echo    [WARNING] Integrator failed. Proceeding with Certificate Fallback.
        ) else (
            echo    [OK] Integrator configured successfully.
        )
    )
)

for /f "delims=" %%x in ('dir /b "%LicensesPath%\client-issuance*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)
for /f "delims=" %%x in ('dir /b "%LicensesPath%\ProPlus2021*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)

:: මෙතනදී KMS Server එක විතරක් set කරනවා, Key එකක් දාන්නේ නෑ (Manual Activation සඳහා)
cscript //nologo "%OSPP%" /sethst:kms8.msguides.com >nul 2>&1
cscript //nologo "%OSPP%" /setprt:1688 >nul 2>&1

:: [9] DEEP VERIFICATION (CERTIFICATE & LICENSE CHECK ONLY)
echo [*] Step 8: Performing Deep System Verification...
cscript //nologo "%OSPP%" /dstatus > "%temp%\ospp_status.txt"

find /i "Office21ProPlus2021VL" "%temp%\ospp_status.txt" >nul
set IsProPlus2021=!errorlevel!

if !IsProPlus2021! equ 0 (
    color 0A
    echo.
    echo ==================================================
    echo    [SUCCESS] SYSTEM READY FOR MANUAL ACTIVATION
    echo ==================================================
    echo.
    echo Opening Microsoft Word...
    echo Please go to Account -^> Change Product Key and enter your key.
    timeout /t 4 >nul
    
    if exist "%_InstallRoot%\Office16\WINWORD.EXE"[cite: 2]
        start "" "%_InstallRoot%\Office16\WINWORD.EXE"
    ) else (
        start winword
    )
) else (
    color 0C
    echo.
    echo [FATAL ERROR] Deep Verification Failed!
    echo The script could not confirm the 2021 Pro Plus license injection.
    pause
)
del "%temp%\ospp_status.txt" >nul 2>&1
