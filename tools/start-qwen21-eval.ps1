$ErrorActionPreference = 'Stop'
$qwenRoot = 'D:/Work/AI/Image/QwenImage21'
$runRoot = Join-Path $qwenRoot 'run'
New-Item -ItemType Directory -Force $runRoot | Out-Null
try {
    $stats = Invoke-RestMethod 'http://127.0.0.1:8191/system_stats' -TimeoutSec 2
    Write-Output 'Qwen evaluation service already available on 8191.'
    exit 0
} catch {}
$config = @"
qwen_evaluation:
    base_path: D:/Work/AI/Image/QwenImage21/models
    diffusion_models: diffusion_models
    text_encoders: text_encoders
    vae: vae
"@
$config | Set-Content -LiteralPath (Join-Path $qwenRoot 'models.yaml') -Encoding utf8
$env:PYTHONIOENCODING = 'utf-8'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$process = Start-Process -FilePath (Join-Path $qwenRoot 'venv/Scripts/python.exe') -ArgumentList @(
    '-s', 'main.py', '--listen', '127.0.0.1', '--port', '8191',
    '--disable-auto-launch', '--disable-all-custom-nodes', '--reserve-vram', '2',
    '--extra-model-paths-config', (Join-Path $qwenRoot 'models.yaml')
) -WorkingDirectory (Join-Path $qwenRoot 'ComfyUI') -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput (Join-Path $runRoot "$stamp-stdout.log") `
  -RedirectStandardError (Join-Path $runRoot "$stamp-stderr.log")
$process.Id | Set-Content -LiteralPath (Join-Path $runRoot 'qwen.pid')
Write-Output "Qwen evaluation service starting: PID $($process.Id), port 8191"
