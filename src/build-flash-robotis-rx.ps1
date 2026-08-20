<#
.SYNOPSIS
Builds, flashes, and verifies the ROBOTIS BIC37 ExpressLRS receiver firmware.

.EXAMPLE
.\build-flash-robotis-rx.ps1

.EXAMPLE
.\build-flash-robotis-rx.ps1 -Port COM7

.EXAMPLE
.\build-flash-robotis-rx.ps1 -BuildOnly

.NOTES
The default 115200 baud rate is intentionally conservative for reliable flashing.
Use -NoPrompt only when the ESP32 is already in its serial download mode.
#>
[CmdletBinding()]
param(
    [string]$Port = "COM39",
    [ValidateRange(9600, 2000000)]
    [int]$Baud = 115200,
    [string]$EnvironmentName = "ROBOTIS_2400_RX_via_UART",
    [switch]$SkipBuild,
    [switch]$BuildOnly,
    [switch]$NoPrompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectDirectory = $PSScriptRoot
$buildDirectory = Join-Path $projectDirectory ".pio\build\$EnvironmentName"

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath"
    }
}

function Find-PlatformIO {
    foreach ($commandName in @("pio", "platformio")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    $candidates = @(
        (Join-Path $env:USERPROFILE ".platformio\penv\Scripts\platformio.exe"),
        (Join-Path $env:USERPROFILE ".platformio\penv\Scripts\pio.exe")
    )

    $temporaryInstallations = Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter "elrs-pio-*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    foreach ($installation in $temporaryInstallations) {
        $candidates += Join-Path $installation.FullName "Scripts\platformio.exe"
        $candidates += Join-Path $installation.FullName "Scripts\pio.exe"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw "PlatformIO was not found. Install it or run the ExpressLRS PlatformIO installer first."
}

function Find-EsptoolPython {
    param([Parameter(Mandatory)][string]$PlatformIOPath)

    $platformIOPython = Join-Path (Split-Path -Parent $PlatformIOPath) "python.exe"
    if (Test-Path -LiteralPath $platformIOPython -PathType Leaf) {
        return $platformIOPython
    }

    foreach ($commandName in @("python", "py")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    throw "Python was not found for esptool."
}

function Find-Esptool {
    $platformIOCore = if ([string]::IsNullOrWhiteSpace($env:PLATFORMIO_CORE_DIR)) {
        Join-Path $env:USERPROFILE ".platformio"
    }
    else {
        $env:PLATFORMIO_CORE_DIR
    }

    $esptool = Join-Path $platformIOCore "packages\tool-esptoolpy\esptool.py"
    if (Test-Path -LiteralPath $esptool -PathType Leaf) {
        return $esptool
    }

    throw "esptool.py was not found at '$esptool'. Build the target once so PlatformIO can install it."
}

$platformIO = Find-PlatformIO
Write-Host "PlatformIO: $platformIO"
Write-Host "Environment: $EnvironmentName"

Push-Location $projectDirectory
try {
    if (-not $SkipBuild) {
        Write-Host "`nBuilding firmware..." -ForegroundColor Cyan
        Invoke-NativeCommand -FilePath $platformIO -ArgumentList @("run", "-e", $EnvironmentName)
    }

    if ($BuildOnly) {
        Write-Host "`nBuild completed: $buildDirectory\firmware.bin" -ForegroundColor Green
        return
    }

    $images = @(
        @{ Address = "0x1000"; File = (Join-Path $buildDirectory "bootloader.bin") },
        @{ Address = "0x8000"; File = (Join-Path $buildDirectory "partitions.bin") },
        @{ Address = "0xe000"; File = (Join-Path $buildDirectory "boot_app0.bin") },
        @{ Address = "0x10000"; File = (Join-Path $buildDirectory "firmware.bin") }
    )

    foreach ($image in $images) {
        if (-not (Test-Path -LiteralPath $image.File -PathType Leaf)) {
            throw "Required image is missing: $($image.File)"
        }
    }

    $availablePorts = [System.IO.Ports.SerialPort]::GetPortNames()
    if ($Port -notin $availablePorts) {
        Write-Warning "$Port is not currently listed. Available ports: $($availablePorts -join ', ')"
    }

    if (-not $NoPrompt) {
        Write-Host "`nPut the receiver in download mode:" -ForegroundColor Yellow
        Write-Host "  1. Hold GPIO0/BOOT low."
        Write-Host "  2. Briefly pulse EN low, then release EN."
        Write-Host "  3. Release GPIO0/BOOT."
        Read-Host "Press Enter when $Port is ready" | Out-Null
    }

    $python = Find-EsptoolPython -PlatformIOPath $platformIO
    $esptool = Find-Esptool
    $commonArguments = @(
        $esptool,
        "--chip", "esp32",
        "--port", $Port,
        "--baud", "$Baud",
        "--before", "no_reset",
        "--after", "no_reset"
    )
    $flashLayout = @()
    foreach ($image in $images) {
        $flashLayout += $image.Address
        $flashLayout += $image.File
    }

    Write-Host "`nFlashing $Port at $Baud baud..." -ForegroundColor Cyan
    Invoke-NativeCommand -FilePath $python -ArgumentList ($commonArguments + @(
        "write_flash",
        "--flash_mode", "dio",
        "--flash_freq", "40m",
        "--flash_size", "4MB"
    ) + $flashLayout)

    Write-Host "`nVerifying flash contents..." -ForegroundColor Cyan
    Invoke-NativeCommand -FilePath $python -ArgumentList ($commonArguments + @(
        "verify_flash",
        "--flash_mode", "dio",
        "--flash_freq", "40m",
        "--flash_size", "4MB"
    ) + $flashLayout)

    Write-Host "`nBuild, flash, and verification completed successfully." -ForegroundColor Green
    Write-Host "Pulse EN or power-cycle the receiver with GPIO0/BOOT released to start it."
}
finally {
    Pop-Location
}
