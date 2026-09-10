:: [7.5] CLEANUP (Parana keys ain kireema)
echo [*] Cleaning up existing product keys to ensure a clean state...
for /f "tokens=8" %%a in ('cscript //nologo "%OSPP%" /dstatus ^| findstr /b /c:"Last 5 characters of installed product key:"') do (
    cscript //nologo "%OSPP%" /unpkey:%%a >nul 2>&1
)

:: [8] SMART CONVERSION (VOLUME - NO AUTO ACTIVATION)
echo [*] Step 7: Forcing Office 2021 Pro Plus Volume Conversion...
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

:: Installing Volume Certificates
for /f "delims=" %%x in ('dir /b "%LicensesPath%\client-issuance*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)
for /f "delims=" %%x in ('dir /b "%LicensesPath%\ProPlus2021*.xrm-ms" 2^>nul') do (
    cscript //nologo "%OSPP%" /inslic:"%LicensesPath%\%%x" >nul 2>&1
)

:: Methanadi Auto-activate karanne naha. Server eka vitharak set karanawa.
echo [*] Setting up Activation Server for manual entry...
cscript //nologo "%OSPP%" /sethst:kms8.msguides.com >nul 2>&1
cscript //nologo "%OSPP%" /setprt:1688 >nul 2>&1

:: [9] LAUNCH FOR MANUAL ACTIVATION
:: (Deep verification eka ain kala, mokada key eka natuwa dstatus eken nama penwanne nathi nisa)
color 0A
echo.
echo ==================================================
echo    [SUCCESS] SYSTEM READY FOR MANUAL ACTIVATION
echo ==================================================
echo.
echo Opening Microsoft Word...
echo Please go to Account -^> Change Product Key.
echo Enter this Key manually: FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH
timeout /t 5 >nul
    
if exist "%_InstallRoot%\Office16\WINWORD.EXE" (
    start "" "%_InstallRoot%\Office16\WINWORD.EXE"
) else (
    start winword
)
