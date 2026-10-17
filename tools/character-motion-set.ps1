param(
    [ValidateSet('Validate')][string]$Action='Validate',
    [Parameter(Mandatory=$true)][string]$Manifest
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskManifest=(Resolve-Path -LiteralPath $Manifest).Path
$taskPython=if($env:CHARACTER_PYTHON){$env:CHARACTER_PYTHON}else{'D:/miniforge/python.exe'}
& $taskPython (Join-Path $taskRoot 'tools/assets/validate_character_motion_set.py') --manifest $taskManifest
if($LASTEXITCODE -ne 0){throw 'Offline motion-set validation failed'}
