# --- start-server.ps1（安定版）---

$ErrorActionPreference = "Stop"

# 0) 作業ディレクトリをスクリプトの場所に固定
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 1) 設定
$Port = 3000
$NgrokPath = "C:\Users\nagar\Downloads\ngrok-v3\ngrok.exe"

# node/ngrok の実体を解決（PATHが通ってなくても拾う）
function Resolve-Bin([string]$name, [string]$fallback=$null) {
  try { (Get-Command $name -ErrorAction Stop).Source } catch { if ($fallback -and (Test-Path $fallback)) { $fallback } else { $null } }
}
$NodePath  = Resolve-Bin "node.exe" "C:\Program Files\nodejs\node.exe"
if (-not $NodePath) { $NodePath = Resolve-Bin "node" "C:\Program Files\nodejs\node.exe" }
if (-not $NodePath) { Write-Error "node が見つかりません。PATHを通すか NodePath を直指定してください。"; exit 1 }
if (-not (Test-Path $NgrokPath)) { Write-Error "ngrok.exe が見つかりません。パスを確認してください。"; exit 1 }
if (-not (Test-Path ".\server.js")) { Write-Error "server.js が $ScriptDir にありません。"; exit 1 }

# 2) ログ
New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
$nodeOut = Join-Path $ScriptDir "logs\node-out.log"
$nodeErr = Join-Path $ScriptDir "logs\node-err.log"
$ngOut   = Join-Path $ScriptDir "logs\ngrok-out.log"
$ngErr   = Join-Path $ScriptDir "logs\ngrok-err.log"

# 3) Node 起動
Write-Host "[1/5] Starting Node.js ($NodePath server.js)…"
$nodeProc = Start-Process -FilePath $NodePath `
  -ArgumentList "server.js" -WorkingDirectory $ScriptDir -PassThru -WindowStyle Hidden `
  -RedirectStandardOutput $nodeOut -RedirectStandardError $nodeErr

# 4) Node ヘルスチェック（最大20回=約10秒）
Write-Host "[2/5] Waiting for http://127.0.0.1:$Port ..."
$ok=$false
for ($i=0; $i -lt 20; $i++) {
  try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port" -UseBasicParsing -TimeoutSec 1
    if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { $ok=$true; break }
  } catch {}
  Start-Sleep -Milliseconds 500
}
if (-not $ok) {
  Write-Host "Nodeが反応しません。ログを確認してください：`n  $nodeOut`n  $nodeErr"
  Write-Host "何かキーで終了します…"
  $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
  if ($nodeProc -and !$nodeProc.HasExited) { Stop-Process -Id $nodeProc.Id -Force }
  exit 1
}

# 5) ngrok 起動（バックグラウンド、ログ保存）
Write-Host "[3/5] Starting ngrok on port $Port ..."
$ngProc = Start-Process -FilePath $NgrokPath `
  -ArgumentList "http $Port" -WorkingDirectory $ScriptDir -PassThru -WindowStyle Hidden `
  -RedirectStandardOutput $ngOut -RedirectStandardError $ngErr

# 6) 公開URL取得：4040のAPIを最大60秒ポーリング
Write-Host "[4/5] Fetching public URL from ngrok API..."
$publicUrl = $null
for ($i=0; $i -lt 60; $i++) {
  try {
    $resp = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 1
    $publicUrl = ($resp.tunnels | Where-Object { $_.public_url -like 'https:*' } | Select-Object -First 1).public_url
    if ($publicUrl) { break }
  } catch {}
  Start-Sleep -Seconds 1
}
if ($publicUrl) {
  Set-Clipboard $publicUrl
  Write-Host "Public URL: $publicUrl"
  Write-Host "(URLをクリップボードにコピーしました)"
} else {
  Write-Host "ngrok のURLが取得できませんでした。ログを確認してください：`n  $ngOut`n  $ngErr"
}

# 7) 終了待ち → 停止
Write-Host "`n[5/5] Press any key to stop Node & ngrok…"
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
Write-Host "Stopping…"
if ($ngProc   -and !$ngProc.HasExited) { Stop-Process -Id $ngProc.Id  -Force }
if ($nodeProc -and !$nodeProc.HasExited) { Stop-Process -Id $nodeProc.Id -Force }
Write-Host "Done. Logs:`n  $nodeOut`n  $nodeErr`n  $ngOut`n  $ngErr"
