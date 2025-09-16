@echo off
echo =================================================================================
echo EXTRACTING ALL IRS XML ZIP FILES - BATCH METHOD
echo =================================================================================

set "SOURCE_DIR=E:\Raw IRS data"
set "EXTRACT_DIR=E:\Raw IRS data\extracted"

if not exist "%EXTRACT_DIR%" mkdir "%EXTRACT_DIR%"

echo.
echo Processing ZIP files...
echo.

set /a total_processed=0
set /a total_xml=0

for %%f in ("%SOURCE_DIR%\*.zip") do (
    echo Processing: %%~nf.zip
    set "extract_subdir=%EXTRACT_DIR%\%%~nf"

    if not exist "!extract_subdir!" mkdir "!extract_subdir!"

    powershell -command "Expand-Archive -Path '%%f' -DestinationPath '!extract_subdir!' -Force"

    if %errorlevel% equ 0 (
        echo   SUCCESS: Extracted to !extract_subdir!
        set /a total_processed+=1

        REM Count XML files in this directory
        for /f %%c in ('dir /b /a-d "!extract_subdir!\*.xml" 2^>nul ^| find /c ".xml"') do set xml_count=%%c
        echo   XML files found: !xml_count!
        set /a total_xml+=!xml_count!

    ) else (
        echo   ERROR: Failed to extract %%~nf.zip
    )
    echo.
)

echo =================================================================================
echo EXTRACTION SUMMARY
echo =================================================================================
echo Total ZIP files processed: %total_processed%
echo Total XML files extracted: %total_xml%
echo Extraction directory: %EXTRACT_DIR%
echo.
echo NEXT STEPS:
echo 1. All ZIP files should now be extracted
echo 2. Ready to run parser on complete dataset
echo 3. Expected: 100,000+ foundations, 1,000,000+ grants
echo.
pause

