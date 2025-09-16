# CORRECTED PowerShell script for IRS XML extraction
# This version properly handles paths and uses reliable extraction methods

$SourceDir = "E:\Raw IRS data"
$ExtractDir = "E:\Raw IRS data\extracted"

Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "IRS XML EXTRACTION - CORRECTED VERSION" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host ""

# Verify source directory exists
if (!(Test-Path $SourceDir)) {
    Write-Host "ERROR: Source directory does not exist: $SourceDir" -ForegroundColor Red
    exit 1
}

# Create extraction directory if needed
if (!(Test-Path $ExtractDir)) {
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
    Write-Host "Created extraction directory: $ExtractDir" -ForegroundColor Green
}

# Get all ZIP files
$zipFiles = Get-ChildItem -Path "$SourceDir\*.zip" | Sort-Object Name
$totalFiles = $zipFiles.Count

Write-Host "Found $totalFiles ZIP files to process from: $SourceDir" -ForegroundColor Yellow
Write-Host "Extracting to: $ExtractDir" -ForegroundColor Yellow
Write-Host ""

$successful = 0
$failed = 0
$totalXmlFiles = 0

foreach ($zipFile in $zipFiles) {
    $index = [array]::IndexOf($zipFiles, $zipFile) + 1
    $fileName = $zipFile.Name
    $fileSizeMB = [math]::Round($zipFile.Length / 1MB, 2)

    Write-Host "$index/$totalFiles : Processing $fileName ($fileSizeMB MB)" -ForegroundColor White

    # Create extraction subdirectory with proper path
    $extractSubdir = Join-Path $ExtractDir $zipFile.BaseName

    if (!(Test-Path $extractSubdir)) {
        New-Item -ItemType Directory -Path $extractSubdir -Force | Out-Null
    }

    try {
        # Use tar command if available (more reliable for large files)
        $tarAvailable = Get-Command tar -ErrorAction SilentlyContinue

        if ($tarAvailable) {
            Write-Host "  Using tar command for extraction..." -ForegroundColor Gray
            $process = Start-Process -FilePath "tar" -ArgumentList "-xf", "`"$($zipFile.FullName)`"", "-C", "`"$extractSubdir`"" -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -eq 0) {
                $xmlCount = (Get-ChildItem -Path $extractSubdir -Recurse -Filter "*.xml" -ErrorAction SilentlyContinue).Count
                Write-Host "  SUCCESS: Extracted $xmlCount XML files using tar" -ForegroundColor Green
                $successful++
                $totalXmlFiles += $xmlCount
            } else {
                throw "tar extraction failed with exit code $($process.ExitCode)"
            }
        } else {
            # Fallback to Expand-Archive
            Write-Host "  Using Expand-Archive..." -ForegroundColor Gray
            Expand-Archive -Path $zipFile.FullName -DestinationPath $extractSubdir -Force

            $xmlCount = (Get-ChildItem -Path $extractSubdir -Recurse -Filter "*.xml" -ErrorAction SilentlyContinue).Count
            Write-Host "  SUCCESS: Extracted $xmlCount XML files using Expand-Archive" -ForegroundColor Green
            $successful++
            $totalXmlFiles += $xmlCount
        }

    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failed++

        # Try alternative method for stubborn files
        Write-Host "  Attempting alternative extraction method..." -ForegroundColor Yellow

        try {
            # Use 7-Zip if available
            $sevenZip = Get-Command "7z" -ErrorAction SilentlyContinue
            if ($sevenZip) {
                Write-Host "  Using 7-Zip..." -ForegroundColor Gray
                $process = Start-Process -FilePath "7z" -ArgumentList "x", "`"$($zipFile.FullName)`"", "-o`"$extractSubdir`"", "-y" -Wait -PassThru -NoNewWindow

                if ($process.ExitCode -eq 0) {
                    $xmlCount = (Get-ChildItem -Path $extractSubdir -Recurse -Filter "*.xml" -ErrorAction SilentlyContinue).Count
                    Write-Host "  SUCCESS: Extracted $xmlCount XML files using 7-Zip" -ForegroundColor Green
                    $successful++
                    $failed--
                    $totalXmlFiles += $xmlCount
                }
            }
        } catch {
            Write-Host "  Alternative method also failed" -ForegroundColor Red
        }
    }

    # Progress update every 5 files
    if ($index % 5 -eq 0 -or $index -eq $totalFiles) {
        Write-Host ""
        Write-Host "Progress: $successful successful, $failed failed, $totalXmlFiles total XML files" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Final summary
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "EXTRACTION COMPLETE" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Final Summary:" -ForegroundColor White
Write-Host "  Total ZIP files: $totalFiles" -ForegroundColor White
Write-Host "  Successful: $successful" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor Red
Write-Host "  Total XML files extracted: $totalXmlFiles" -ForegroundColor Green
Write-Host ""
Write-Host "Files extracted to: $ExtractDir" -ForegroundColor White
Write-Host ""

# Show extraction results
Write-Host "Extracted directories:" -ForegroundColor White
Get-ChildItem -Path $ExtractDir -Directory | Sort-Object Name | ForEach-Object {
    $xmlCount = (Get-ChildItem -Path $_.FullName -Recurse -Filter "*.xml" -ErrorAction SilentlyContinue).Count
    Write-Host "  $($_.Name): $xmlCount XML files" -ForegroundColor Gray
}

