param(
    [ValidateSet('Play','Check','Stills','Record')][string]$Mode = 'Play',
    [string]$OutputDir,
    [string]$GodotExe,
    [string]$FfmpegExe = 'D:/Program Files/ImageMagick-7.1.1-Q16-HDRI/ffmpeg.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotExe) { $GodotExe = Join-Path $projectRoot 'Local/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotExe)) { throw "Godot executable is missing: $GodotExe" }
$runtimeRoot = Join-Path $projectRoot 'Godot'
$localDir = Join-Path $projectRoot 'Local/Harbor-v02'
New-Item -ItemType Directory -Force -Path $localDir | Out-Null
$importLog = Join-Path $localDir 'import-latest.log'
& $GodotExe --headless --path $runtimeRoot --editor --import --quit --log-file $importLog | Out-Null
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' -Quiet)) {
    throw "Godot import failed; inspect $importLog"
}
if ($Mode -eq 'Check') {
    & $GodotExe --headless --path $runtimeRoot --script res://tests/harbor_checks.gd
    if ($LASTEXITCODE -ne 0) { throw 'Harbor functional checks failed.' }
    return
}
# Start-Process uses a Windows command line. Quote each argument, rather than relying on
# array joining to preserve project paths containing spaces.
function Join-NativeArguments([string[]]$Values) {
    return ($Values | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
}
if ($Mode -eq 'Play') {
    Start-Process -FilePath $GodotExe -ArgumentList (Join-NativeArguments @('--path',$runtimeRoot,'res://harbor.tscn','--position','80,80','--resolution','1280x720')) -WindowStyle Normal
    return
}
if (-not $OutputDir) { $OutputDir = Join-Path $projectRoot ('Artifacts/Harbor-v02/review-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
if (Test-Path -LiteralPath $OutputDir) { throw "Choose a new output directory; existing evidence is retained: $OutputDir" }
New-Item -ItemType Directory -Path $OutputDir | Out-Null
$runLog = Join-Path $OutputDir 'godot-run.log'
$engineArguments = @('--path',$runtimeRoot,'res://harbor.tscn','--position','-2000,-2000','--resolution','1600x900','--fixed-fps','30','--log-file',$runLog)
if ($Mode -eq 'Record') {
    if (-not (Test-Path -LiteralPath $FfmpegExe)) { throw "FFmpeg executable is missing: $FfmpegExe" }
    $rawMovie = Join-Path $localDir ('harbor-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.avi')
    $engineArguments += @('--write-movie',$rawMovie,'--disable-vsync','--quit-after','905','--','--autoplay','--review-tour',"--capture-dir=$OutputDir")
} else {
    $engineArguments += @('--quit-after','510','--','--autoplay',"--capture-dir=$OutputDir")
}
$renderProcess = Start-Process -FilePath $GodotExe -ArgumentList (Join-NativeArguments $engineArguments) -WindowStyle Hidden -PassThru
$renderProcess.WaitForExit()
if ($renderProcess.ExitCode -ne 0 -or (Select-String -LiteralPath $runLog -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' -Quiet)) {
    throw "Godot capture failed; inspect $runLog"
}
if (-not (Test-Path -LiteralPath (Join-Path $OutputDir 'capture-report.json'))) { throw 'Capture did not reach its final report.' }
if ($Mode -eq 'Record') {
    $moviePath = Join-Path $OutputDir 'harbor-tour.mp4'
    & $FfmpegExe -hide_banner -loglevel warning -i $rawMovie -an -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart $moviePath
    if ($LASTEXITCODE -ne 0) { throw 'Movie encoding failed.' }
}
Write-Output "Harbor evidence: $OutputDir"
