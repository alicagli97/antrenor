# Antrenör sunucusunu durdurur (API + tarama işçisi).
$durduruldu = 0
Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
    Where-Object { $_.CommandLine -like "*app.main:app*" -or $_.CommandLine -like "*worker.py*" } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force
        Write-Host "durduruldu: PID $($_.ProcessId)"
        $script:durduruldu++
    }
if ($durduruldu -eq 0) { Write-Host "calisan surec bulunamadi" }
