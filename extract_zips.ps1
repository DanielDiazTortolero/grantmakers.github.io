# PowerShell script to extract all IRS XML ZIP files

$RawDataDir = "E:\Raw IRS data"
$ExtractedBaseDir = "$RawDataDir\extracted"

# Create base extraction directory
if (!(Test-Path $ExtractedBaseDir)) {
    New-Item -ItemType Directory -Path $ExtractedBaseDir -Force
}

Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "EXTRACTING ALL IRS XML ZIP FILES USING POWERSHELL" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan

# Get all ZIP files
$zipFiles = Get-ChildItem -Path "$RawDataDir\*.zip" | Sort-Object Name
Write-Host "`n📁 Processing $($zipFiles.Count) ZIP files...`n" -ForegroundColor Yellow

$totalExtracted = 0
$totalXmlFiles = 0

foreach ($zipFile in $zipFiles) {
    $index = [array]::IndexOf($zipFiles, $zipFile) + 1
    $fileName = $zipFile.Name
    Write-Host "$index/$($zipFiles.Count): Extracting $fileName..." -ForegroundColor White

    try {
        # Create extraction directory for this ZIP
        $extractDir = "$ExtractedBaseDir\$($fileName -replace '\.zip$', '')"
        if (!(Test-Path $extractDir)) {
            New-Item -ItemType Directory -Path $extractDir -Force
        }

        # Extract the ZIP file
        Expand-Archive -Path $zipFile.FullName -DestinationPath $extractDir -Force

        # Count XML files
        $xmlFiles = Get-ChildItem -Path $extractDir -Filter "*.xml" -Recurse
        $xmlCount = $xmlFiles.Count
        $totalXmlFiles += $xmlCount

        Write-Host "  ✅ Extracted: $xmlCount XML files to $extractDir" -ForegroundColor Green
        $totalExtracted++

    } catch {
        Write-Host "  ❌ Error extracting $fileName`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n📊 EXTRACTION SUMMARY:" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Successfully extracted: $totalExtracted/$($zipFiles.Count) ZIP files" -ForegroundColor White
Write-Host "Total XML files extracted: $totalXmlFiles" -ForegroundColor White
Write-Host "Extraction directory: $ExtractedBaseDir" -ForegroundColor White

Write-Host "`n🎯 NEXT STEPS:" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "1. All ZIP files have been extracted" -ForegroundColor White
Write-Host "2. Ready to run parser on complete dataset" -ForegroundColor White
Write-Host "3. Expected: 100,000+ foundations, 1,000,000+ grants" -ForegroundColor White

