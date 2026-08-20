# Antrenör sunucusunu bu bilgisayarda başlatır (API + tarama işçisi).
# Kullanım:  powershell -ExecutionPolicy Bypass -File scripts\windows\baslat.ps1

$ErrorActionPreference = "Stop"
$kok = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # ...\backend
Set-Location $kok

$veri = Join-Path $kok "data"
New-Item -ItemType Directory -Force -Path $veri | Out-Null

# .env dosyası varsa ortam değişkenlerini yükle
$envDosya = Join-Path $kok ".env"
if (Test-Path $envDosya) {
    Get-Content $envDosya | ForEach-Object {
        if ($_ -match '^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2].Trim('"'), "Process")
        }
    }
    Write-Host ".env yuklendi"
}

$env:PYTHONIOENCODING = "utf-8"
$env:ENABLE_SCHEDULER = "0"        # tarama ayrı süreçte

# Gerçek python.exe'yi bul: PATH'te Microsoft Store kısayolu veya uzantısız
# kabuk dosyaları python'u gölgeleyebiliyor.
$python = (Get-Command python -All -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -like "*.exe" -and $_.Source -notlike "*WindowsApps*" } |
    Select-Object -First 1).Source
if (-not $python) { $python = (Get-Command py -ErrorAction SilentlyContinue).Source }
if (-not $python) { throw "python bulunamadi. Python 3.12 kurulu mu?" }
Write-Host "python: $python"

function Baslat($ad, $arglar, $log) {
    $mevcut = Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
        Where-Object { $_.CommandLine -like "*$ad*" }
    if ($mevcut) {
        Write-Host "$ad zaten calisiyor (PID $($mevcut.ProcessId))"
        return
    }
    $p = Start-Process -FilePath $python -ArgumentList $arglar `
        -WorkingDirectory $kok -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Write-Host "$ad basladi (PID $($p.Id)) -> $log"
}

Baslat "app.main:app" @("-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000") `
       (Join-Path $veri "api.log")
Baslat "worker.py"    @("-u", "scripts/worker.py") (Join-Path $veri "worker.log")

Start-Sleep -Seconds 6
try {
    $saglik = Invoke-RestMethod "http://127.0.0.1:8000/ready" -TimeoutSec 10
    Write-Host ""
    Write-Host "API hazir. Duyuru sayisi: $($saglik.duyuru_sayisi)"
} catch {
    Write-Warning "API henuz yanit vermiyor, data\api.log dosyasina bakin."
}

$ip = (Get-NetIPConfiguration | Where-Object { $_.NetProfile.IPv4Connectivity -eq "Internet" } |
       Select-Object -First 1).IPv4Address.IPAddress
Write-Host ""
Write-Host "Bu bilgisayardan : http://127.0.0.1:8000"
Write-Host "Ayni Wi-Fi'dan   : http://${ip}:8000   (telefon buraya baglanacak)"
Write-Host "Durdurmak icin   : scripts\windows\durdur.ps1"
