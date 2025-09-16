# Comprehensive PowerShell script to extract all IRS XML ZIP files
# This script will process each ZIP file systematically and verify extraction

param(
    [string]$SourceDir = "E:\Raw IRS data",
    [string]$ExtractDir = "E:\Raw IRS data\extracted",
    [int]$MaxRetries = 3
)

# Create extraction directory if it doesn't exist
if (!(Test-Path $ExtractDir)) {
    New-Item -ItemType Directory -Path $ExtractDir -Force
    Write-Host "Created extraction directory: $ExtractDir" -ForegroundColor Green
}

Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "COMPREHENSIVE IRS XML ZIP EXTRACTION SCRIPT" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host ""

# Get all ZIP files
$zipFiles = Get-ChildItem -Path "$SourceDir\*.zip" | Sort-Object Name
$totalFiles = $zipFiles.Count

Write-Host "Found $totalFiles ZIP files to process:" -ForegroundColor Yellow
Write-Host ""

# Initialize counters
$totalExtracted = 0
$totalXmlFiles = 0
$successfulExtractions = 0
$failedExtractions = 0

# Process each ZIP file
foreach ($zipFile in $zipFiles) {
    $index = [array]::IndexOf($zipFiles, $zipFile) + 1
    $fileName = $zipFile.Name
    $fileSizeMB = [math]::Round($zipFile.Length / 1MB, 2)

    Write-Host "$index/$totalFiles : Processing $fileName ($fileSizeMB MB)" -ForegroundColor White

    # Create extraction subdirectory
    $extractSubdir = "$ExtractDir\$($zipFile.BaseName)"

    if (!(Test-Path $extractSubdir)) {
        New-Item -ItemType Directory -Path $extractSubdir -Force | Out-Null
    }

    # Attempt extraction with retry logic
    $extractionSuccess = $false
    $retryCount = 0

    while (!$extractionSuccess -and $retryCount -lt $MaxRetries) {
        try {
            $retryCount++
            if ($retryCount -gt 1) {
                Write-Host "  Retry $retryCount/$MaxRetries..." -ForegroundColor Yellow
            }

            # Extract the ZIP file
            Expand-Archive -Path $zipFile.FullName -DestinationPath $extractSubdir -Force

            # Verify extraction by checking for XML files
            $xmlFiles = Get-ChildItem -Path $extractSubdir -Recurse -Filter "*.xml" -ErrorAction SilentlyContinue
            $xmlCount = $xmlFiles.Count

            if ($xmlCount -gt 0) {
                $extractionSuccess = $true
                $successfulExtractions++
                $totalXmlFiles += $xmlCount
                Write-Host "  SUCCESS: Extracted $xmlCount XML files" -ForegroundColor Green
            } else {
                Write-Host "  WARNING: No XML files found after extraction" -ForegroundColor Yellow
                $extractionSuccess = $true # Consider it successful if no errors occurred
            }

        } catch {
            Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red

            if ($retryCount -lt $MaxRetries) {
                Write-Host "  Waiting 5 seconds before retry..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
            } else {
                $failedExtractions++
                Write-Host "  FAILED: Maximum retries exceeded" -ForegroundColor Red
            }
        }
    }

    # Progress update
    if ($index % 5 -eq 0 -or $index -eq $totalFiles) {
        Write-Host ""
        Write-Host "Progress: $successfulExtractions successful, $failedExtractions failed, $totalXmlFiles total XML files" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Final summary
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "EXTRACTION COMPLETE" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor White
Write-Host "  Total ZIP files processed: $totalFiles" -ForegroundColor White
Write-Host "  Successful extractions: $successfulExtractions" -ForegroundColor Green
Write-Host "  Failed extractions: $failedExtractions" -ForegroundColor Red
Write-Host "  Total XML files extracted: $totalXmlFiles" -ForegroundColor Green
Write-Host ""

if ($failedExtractions -gt 0) {
    Write-Host "Warning: $failedExtractions files failed to extract. Check the files above." -ForegroundColor Yellow
}

Write-Host "Extraction directory: $ExtractDir" -ForegroundColor White
Write-Host ""

# List all extracted directories
Write-Host "Extracted directories:" -ForegroundColor White
Get-ChildItem -Path $ExtractDir -Directory | Sort-Object Name | ForEach-Object {
    $xmlCount = (Get-ChildItem -Path $_.FullName -Recurse -Filter "*.xml" -ErrorAction SilentlyContinue).Count
    Write-Host "  $($_.Name): $xmlCount XML files" -ForegroundColor Gray
}
