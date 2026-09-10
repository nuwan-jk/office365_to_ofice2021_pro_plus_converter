@echo off
title Office 2021 Pro Plus - Setup
color 07

:: [1] GETTING ADMIN RIGHTS
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting Administrative Privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
exit /B

:gotAdmin
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
pushd "%CD%"
CD /D "%~dp0"

:: [2] FINDING OFFICE INSTALLATION PATH
set "OSPP="
for %%a in (
    "%ProgramFiles%\Microsoft Office\Office16\ospp.vbs"
    "%ProgramFiles(x86)%\Microsoft Office\Office16\ospp.vbs"
    "%ProgramW6432%\Microsoft Office\Office16\ospp.vbs"
) do (
    if exist "%%a" set "OSPP=%%a"
)

if "%OSPP%"=="" (
    color 0C
    echo [FATAL ERROR] OSPP.VBS not found! Is Office 16/2021 installed?
    pause
    exit /b
)

set "_InstallRoot=%OSPP:\Office16\ospp.vbs=%"
set "LicensesPath=%_InstallRoot%\root\Licenses16"

:: [3] CLEANUP - REMOVING OLD LICENSES
echo [*] Preparing system...
for /f "tokens=8" %%a in ('cscript //nologo "%OSPP%" /dstatus ^| findstr /i "Last 5"') do (
    cscript //nologo "%OSPP%" /unpkey:%%a >nul 2>&1
)

:: [4] VOLUME CERTIFICATES INSTALLATION
echo [*] Configuring licenses...
if exist "%LicensesPath%\client-issuance*.xrm-ms" (
    for /f "delims=" %%x in ('dir /b "%LicensesPath%\client-issuance*.xrm-ms" 2^>nul') do (
        cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
    )
)
if exist "%LicensesPath%\ProPlus2021*.xrm-ms" (
    for /f "delims=" %%x in ('dir /b "%LicensesPath%\ProPlus2021*.xrm-ms" 2^>nul') do (
        cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
    )
)

:: [5] KMS SERVER SETUP
echo [*] Finalizing configuration...
cscript //nologo "%OSPP%" /sethst:kms8.msguides.com >nul 2>&1
cscript //nologo "%OSPP%" /setprt:1688 >nul 2>&1

:: [6] LAUNCH
color 0A
echo.
echo ==================================================
echo    [SUCCESS] SYSTEM READY
echo ==================================================
echo.
echo Opening Microsoft Word...
timeout /t 5 >nul

if exist "%_InstallRoot%\root\Office16\WINWORD.EXE" (
    start "" "%_InstallRoot%\root\Office16\WINWORD.EXE"
) else if exist "%_InstallRoot%\Office16\WINWORD.EXE" (
    start "" "%_InstallRoot%\Office16\WINWORD.EXE"
) else (
    start winword
)
exit
