@echo off
REM Yerel kopru: GitHub'dan taranamayan kaynaklari bu bilgisayardan ceker.
REM Gorev Zamanlayici bunu gunde birkac kez calistirir.
REM Elle denemek icin bu dosyaya cift tiklamak yeterli.

setlocal
set PYTHONIOENCODING=utf-8
set PYTHONUTF8=1

set KOK=%~dp0..\..\..
set GUNLUK=%KOK%\backend\data\kopru.log

if not exist "%KOK%\backend\data" mkdir "%KOK%\backend\data"

echo. >> "%GUNLUK%"
echo ==================== %date% %time% ==================== >> "%GUNLUK%"

"C:\Users\PEGASUS\AppData\Local\Programs\Python\Python312\python.exe" "%KOK%\backend\scripts\local_bridge.py" >> "%GUNLUK%" 2>&1
set SONUC=%ERRORLEVEL%

echo bitis kodu: %SONUC% >> "%GUNLUK%"
exit /b %SONUC%
