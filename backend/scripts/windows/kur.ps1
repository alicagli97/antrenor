# Bu bilgisayarı sunucu olarak hazırlar:
#   1) Windows Güvenlik Duvarı'nda 8000 portunu yerel ağa açar
#   2) Bilgisayar açıldığında sunucuyu otomatik başlatan görev oluşturur
#   3) Uyku ayarını uyarır (uyuyan bilgisayar veri akışını keser)
#
# YÖNETİCİ olarak çalıştırın:
#   powershell -ExecutionPolicy Bypass -File scripts\windows\kur.ps1

$ErrorActionPreference = "Stop"
$kok = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$baslat = Join-Path $PSScriptRoot "baslat.ps1"

$yonetici = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $yonetici) {
    Write-Warning "Bu betigi yonetici olarak calistirin (guvenlik duvari ve gorev olusturma icin)."
    exit 1
}

# 1) Güvenlik duvarı — yalnızca yerel ağ (Private profil)
$kural = "Antrenor API 8000"
if (-not (Get-NetFirewallRule -DisplayName $kural -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $kural -Direction Inbound -Action Allow `
        -Protocol TCP -LocalPort 8000 -Profile Private | Out-Null
    Write-Host "guvenlik duvari kurali eklendi: $kural (yalnizca yerel ag)"
} else {
    Write-Host "guvenlik duvari kurali zaten var"
}

# 2) Açılışta otomatik başlat
$gorev = "AntrenorSunucu"
$eylem = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$baslat`"" `
    -WorkingDirectory $kok
$tetik = New-ScheduledTaskTrigger -AtLogOn
$ayar = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName $gorev -Action $eylem -Trigger $tetik `
    -Settings $ayar -Force -RunLevel Limited | Out-Null
Write-Host "gorev olusturuldu: $gorev (oturum acilisinda baslar)"

# 3) Uyku uyarısı
$uyku = powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String "Current AC Power Setting Index"
Write-Host ""
Write-Host "Uyku ayari: $uyku"
Write-Host "Bilgisayar uyursa duyuru taramasi ve uygulamanin veri akisi durur."
Write-Host "Kapatmak icin:  powercfg /change standby-timeout-ac 0"
Write-Host ""
Write-Host "Kurulum tamam. Baslatmak icin: scripts\windows\baslat.ps1"
