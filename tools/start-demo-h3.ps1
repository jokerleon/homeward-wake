param([int]$Port=8196)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$packageRoot='D:\Work\AI\Video\minimax\Comfyui-WF-2026.8.8'
$serviceDir=Join-Path $projectRoot 'Local\ReturnDemo\h3-service'
New-Item -ItemType Directory -Force -Path $serviceDir | Out-Null
try {
    $existing=Invoke-RestMethod -Uri "http://127.0.0.1:$Port/system_stats" -TimeoutSec 2
    throw "Port $Port already serves a process. Inspect the existing launch receipt before reusing it."
} catch {
    if ($_.Exception.Message -like 'Port * already*') { throw }
}
$env:PYTHONIOENCODING='utf-8'
$env:OMP_NUM_THREADS='8'
$env:MKL_NUM_THREADS='8'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$stdout=Join-Path $serviceDir "$stamp-stdout.log"
$stderr=Join-Path $serviceDir "$stamp-stderr.log"
$arguments=@('-s','main.py','--listen','127.0.0.1','--port',"$Port",
    '--disable-auto-launch','--enable-dynamic-vram','--vram-headroom','2',
    '--disable-async-offload','--disable-pinned-memory','--cache-ram','12',
    '--disable-all-custom-nodes','--whitelist-custom-nodes',
    'comfyui-minimax-h3-audio-T8','comfyui-videohelpersuite')
$h3Process=Start-Process -FilePath (Join-Path $packageRoot 'python\python.exe') -ArgumentList $arguments `
    -WorkingDirectory (Join-Path $packageRoot 'ComfyUI') -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
[pscustomobject]@{pid=$h3Process.Id;port=$Port;started=(Get-Date).ToString('o');exe=(Join-Path $packageRoot 'python\python.exe');args=$arguments;stdout=$stdout;stderr=$stderr;owner='chess-return-demo-local-assets';reason='Use the supported dynamic-VRAM safetensors reader after the legacy loader crashed before sampling.'} |
    ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $serviceDir 'launch.json') -Encoding utf8
Write-Output "Local H3 task service starting on port $Port, PID $($h3Process.Id)."
