# Banan demo bootstrap — opens all 5 services for a live presentation.
# Run from PowerShell at the repo root:  .\start-all.ps1
#
# Brings up:
#   - Postgres + Redis (Docker)
#   - NestJS backend on :3000
#   - Customer / Merchant / Kitchen Flutter web in release mode
#
# Each Flutter app takes ~2 minutes to compile the first time. Subsequent
# runs are faster because dart2js caches. Keep all PowerShell windows open
# during the demo — closing one stops that service.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

Step "1/5  Starting Docker containers (Postgres + Redis)"
Push-Location "$root\backend"
docker compose up -d
Pop-Location
Start-Sleep -Seconds 3

Step "2/5  Starting backend (NestJS) on :3000"
Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-Command',
    "Set-Location '$root\backend'; corepack pnpm start:dev"
)
Start-Sleep -Seconds 5

Step "3/5  Starting customer app on :8081"
Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-Command',
    "Set-Location '$root\apps\banan_customer'; flutter run -d web-server --release --web-port 8081 --web-hostname 0.0.0.0"
)

Step "4/5  Starting merchant app on :8082"
Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-Command',
    "Set-Location '$root\apps\banan_merchant'; flutter run -d web-server --release --web-port 8082 --web-hostname 0.0.0.0"
)

Step "5/5  Starting kitchen app on :8083"
Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-Command',
    "Set-Location '$root\apps\banan_kitchen'; flutter run -d web-server --release --web-port 8083 --web-hostname 0.0.0.0"
)

Write-Host ""
Write-Host "All services launching in separate windows." -ForegroundColor Green
Write-Host "Wait ~2-3 minutes for first-time Flutter builds to finish." -ForegroundColor Yellow
Write-Host ""
Write-Host "Demo URLs:" -ForegroundColor Cyan
Write-Host "  Customer: http://localhost:8081"
Write-Host "  Merchant: http://localhost:8082"
Write-Host "  Kitchen : http://localhost:8083"
Write-Host "  Backend : http://localhost:3000/api/v1/health"
Write-Host ""
Write-Host "Test accounts (password: banan123):" -ForegroundColor Cyan
Write-Host "  customer@banan.local"
Write-Host "  merchant@banan.local             (Le Thanh Ton)"
Write-Host "  merchant-suvanhanh@banan.local   (Su Van Hanh)"
Write-Host "  merchant-ngoquanghuy@banan.local (Ngo Quang Huy)"
Write-Host "  merchant-truongsa@banan.local    (Truong Sa)"
Write-Host "  kitchen@banan.local"
Write-Host "  admin@banan.local"
