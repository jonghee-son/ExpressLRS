<#
.SYNOPSIS
Builds the ROBOTIS BIC37 production candidates and laboratory test firmware.

.NOTES
The resulting files are certification candidates. Regulatory approval requires
measurements from an accredited laboratory on the final hardware and antenna.
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "artifacts\robotis-regulatory"),
    [AllowEmptyString()]
    [string]$BindPhrase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$buildHelper = Join-Path $PSScriptRoot "build-flash-robotis-rx.ps1"
$environments = @(
    "ROBOTIS_2400_RX_CE_via_UART",
    "ROBOTIS_2400_RX_CE_CERT_TEST_via_UART",
    "ROBOTIS_2400_RX_FCC_via_UART",
    "ROBOTIS_2400_RX_FCC_CERT_TEST_via_UART",
    "ROBOTIS_2400_RX_KC_CANDIDATE_via_UART",
    "ROBOTIS_2400_RX_KC_CERT_TEST_via_UART",
    "ROBOTIS_2400_RX_JP_GITEKI_CANDIDATE_via_UART",
    "ROBOTIS_2400_RX_JP_GITEKI_CERT_TEST_via_UART"
)

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$manifest = @()

foreach ($environmentName in $environments) {
    Write-Host "`nBuilding $environmentName" -ForegroundColor Cyan
    $helperArguments = @{
        EnvironmentName = $environmentName
        BuildOnly = $true
    }
    if ($PSBoundParameters.ContainsKey("BindPhrase")) {
        $helperArguments.BindPhrase = $BindPhrase
    }
    & $buildHelper @helperArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed for $environmentName"
    }

    $source = Join-Path $PSScriptRoot ".pio\build\$environmentName\firmware.bin"
    $destination = Join-Path $OutputDirectory "$environmentName.bin"
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $hash = Get-FileHash -LiteralPath $destination -Algorithm SHA256
    $manifest += [PSCustomObject]@{
        Environment = $environmentName
        File = Split-Path -Leaf $destination
        SHA256 = $hash.Hash.ToLowerInvariant()
    }
}

$manifestPath = Join-Path $OutputDirectory "manifest.json"
$manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Host "`nFirmware and SHA-256 manifest written to $OutputDirectory" -ForegroundColor Green
