param(
    [ValidateSet('Play','Check','Capture','Record','Review')][string]$Mode = 'Play',
    [ValidateSet('story','sea','deck')][string]$Scene = 'story',
    [string]$OutputDir,
    [string]$GodotExe
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotExe) { $GodotExe = Join-Path $projectRoot 'Local/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
$runtimeRoot = Join-Path $projectRoot 'Godot'
$localDir = Join-Path $projectRoot 'Local/ReturnDemo'
New-Item -ItemType Directory -Force -Path $localDir | Out-Null
$importLog = Join-Path $localDir 'import-latest.log'
& $GodotExe --headless --path $runtimeRoot --editor --import --quit --log-file $importLog | Out-Null
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' -Quiet)) { throw "Import failed: $importLog" }
if ($Mode -eq 'Check') {
    $checkLog = Join-Path $localDir 'checks-latest.log'
    & $GodotExe --headless --path $runtimeRoot --script res://tests/demo_checks.gd --quit-after 1500 --log-file $checkLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $checkLog -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' -Quiet) -or -not (Select-String -LiteralPath $checkLog -Pattern 'DEMO_CHECKS' -Quiet)) { throw 'Demo checks failed; inspect Local/ReturnDemo/checks-latest.log.' }
    return
}
function Join-NativeArguments([string[]]$Values) {
    return ($Values | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
}
$runArgs = @('--path',$runtimeRoot,'res://return_demo.tscn','--resolution','1600x900')
if ($Mode -eq 'Play') {
    $runArgs += @('--position','70,50','--',"--demo-scene=$Scene")
    $interactiveGodotExe = $GodotExe.Replace('_console.exe','.exe')
    if (-not (Test-Path -LiteralPath $interactiveGodotExe)) { $interactiveGodotExe = $GodotExe }
    Start-Process -FilePath $interactiveGodotExe -ArgumentList (Join-NativeArguments $runArgs) -WindowStyle Normal
    return
}
if (-not $OutputDir) { $OutputDir = Join-Path $projectRoot ('Artifacts/ReturnDemo/' + $Scene + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
if (Test-Path -LiteralPath $OutputDir) { throw "Use a new evidence directory: $OutputDir" }
New-Item -ItemType Directory -Path $OutputDir | Out-Null
$runLog = Join-Path $OutputDir 'godot.log'
if ($Mode -eq 'Review') {
    $runArgs += @('--position','70,50','--log-file',$runLog,'--',"--demo-scene=$Scene","--demo-manual-review-dir=$OutputDir")
    $interactiveGodotExe = $GodotExe.Replace('_console.exe','.exe')
    # Review is the interactive game window; helpers and captures remain hidden.
    $reviewProcess = Start-Process -FilePath $interactiveGodotExe -ArgumentList (Join-NativeArguments $runArgs) -WindowStyle Normal -PassThru
    [pscustomobject]@{pid=$reviewProcess.Id;owner='chess-demo-manual-review';output=$OutputDir;args=$runArgs} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDir 'launch.json') -Encoding utf8
    Write-Output "Manual review ready; F12 saves a GPU frame. User save is protected: $OutputDir"
    return
}
$runArgs += @('--position','-2000,-2000','--fixed-fps','30','--log-file',$runLog)
if ($Mode -eq 'Record') {
    $movie = Join-Path $localDir ($Scene + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.avi')
    $runArgs += @('--write-movie',$movie,'--disable-vsync')
}
$runArgs += @('--',"--demo-scene=$Scene","--demo-review-dir=$OutputDir")
$process = Start-Process -FilePath $GodotExe -ArgumentList (Join-NativeArguments $runArgs) -WindowStyle Hidden -PassThru
$process.WaitForExit()
if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $runLog -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' -Quiet)) { throw "Runtime failed: $runLog" }
if (-not (Test-Path -LiteralPath (Join-Path $OutputDir 'report.json'))) { throw 'Runtime did not complete the review.' }
if ($Mode -eq 'Record') {
    & 'D:/Program Files/ImageMagick-7.1.1-Q16-HDRI/ffmpeg.exe' -hide_banner -loglevel warning -i $movie -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -c:a aac -movflags +faststart (Join-Path $OutputDir 'demo.mp4')
    if ($LASTEXITCODE -ne 0) { throw 'Recording encode failed.' }
}
Write-Output "Demo evidence: $OutputDir"
