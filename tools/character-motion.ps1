param(
    [ValidateSet('Package','Validate')][string]$Action='Package',
    [Parameter(Mandatory=$true)][string]$Recipe
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskRecipe=(Resolve-Path -LiteralPath $Recipe).Path
$taskSpec=Get-Content -LiteralPath $taskRecipe -Raw | ConvertFrom-Json
$taskPython=if($env:CHARACTER_PYTHON){$env:CHARACTER_PYTHON}else{'D:/miniforge/python.exe'}
if($Action -eq 'Package') {
    & $taskPython (Join-Path $taskRoot 'tools/assets/package_character_motion.py') --spec $taskRecipe
} else {
    $taskManifest=Join-Path (Join-Path $taskRoot $taskSpec.output) 'motion.json'
    if(-not(Test-Path -LiteralPath $taskManifest)){throw 'Package manifest not found'}
    & $taskPython (Join-Path $taskRoot 'tools/assets/validate_character_motion_pack.py') --manifest $taskManifest
}
if($LASTEXITCODE -ne 0){throw "Offline character $Action failed"}
