[CmdletBinding()]
param(
    [string[]]$Roots = @('Assets', 'Artifacts'),
    [string]$OutputDirectory = 'Artifacts/asset-inventory'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputRoot = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
} else {
    Join-Path $repoRoot $OutputDirectory
}

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$summaries = @()

foreach ($root in $Roots) {
    $rootPath = if ([System.IO.Path]::IsPathRooted($root)) {
        $root
    } else {
        Join-Path $repoRoot $root
    }

    if (-not (Test-Path -LiteralPath $rootPath)) {
        Write-Warning "Skipping missing root: $rootPath"
        continue
    }

    $resolvedRoot = (Resolve-Path -LiteralPath $rootPath).Path
    $safeName = ($root -replace '[^A-Za-z0-9._-]', '_')
    $csvPath = Join-Path $outputRoot ("asset-inventory-$safeName-$timestamp.csv")
    $files = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Force -ErrorAction Stop)

    $records = foreach ($file in $files) {
        [pscustomobject]@{
            relative_path = [System.IO.Path]::GetRelativePath($resolvedRoot, $file.FullName)
            bytes = [long]$file.Length
            extension = $file.Extension.ToLowerInvariant()
            last_write_utc = $file.LastWriteTimeUtc.ToString('o')
        }
    }

    $records | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
    $totalBytes = [long](($files | Measure-Object -Property Length -Sum).Sum)

    $summaries += [pscustomobject]@{
        root = $resolvedRoot
        file_count = $files.Count
        bytes = $totalBytes
        gib = [math]::Round($totalBytes / 1GB, 3)
        inventory_csv = $csvPath
    }
}

$summaryPath = Join-Path $outputRoot ("asset-inventory-summary-$timestamp.json")
$summaries | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding utf8

$summaries | Format-Table -AutoSize
Write-Output "Summary: $summaryPath"
