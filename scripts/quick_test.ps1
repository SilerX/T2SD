param(
    [int]$NC = 2,
    [int]$N = 1000,
    [int]$Rate = 50,
    [double]$FR = 0.0,
    [int]$Spike = 0,
    [int]$WaitAfter = 30
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "[1/5] Limpiando entorno previo..."
docker compose down -v --remove-orphans 2>&1 | Out-Null

$env:NUM_CONSUMERS = "$NC"
$env:N_CONSULTAS = "$N"
$env:RATE = "$Rate"
$env:FAILURE_RATE = "$FR"
$env:SPIKE = "$Spike"
$env:DIST = "zipf"

Write-Host "[2/5] Levantando TODO en una sola operacion (consumidor x$NC + dependencias + traffic gen)..."
docker compose up -d --build --scale consumidor=$NC

Write-Host ""
Write-Host "[3/5] Esperando a que generador-trafico termine de publicar las $N consultas..."
docker wait generador-trafico | Out-Null
Write-Host "[INFO] generador-trafico finalizo. Ultimos logs:"
docker logs generador-trafico --tail 5

Write-Host ""
Write-Host "[4/5] Esperando $WaitAfter s para que los consumers procesen el backlog..."
Start-Sleep -Seconds $WaitAfter

Write-Host ""
Write-Host "TODOS los contenedores del proyecto (incluyendo exited):"
docker compose ps -a --format "table {{.Name}}`t{{.Status}}`t{{.State}}"

Write-Host ""
Write-Host "===================== Logs consumidor-1 ====================="
docker logs t2sd-consumidor-1 --tail 25 2>&1
Write-Host ""
Write-Host "===================== Logs consumidor-2 ====================="
docker logs t2sd-consumidor-2 --tail 25 2>&1
Write-Host ""
Write-Host "===================== Logs consumidor-retry ====================="
docker logs consumidor-retry --tail 25 2>&1

Write-Host ""
Write-Host "[5/5] Consultando metricas..."
Write-Host ""
Write-Host "===================== STATS ====================="
try {
    $stats = Invoke-RestMethod -Uri "http://localhost:5001/stats" -TimeoutSec 10
    $stats | ConvertTo-Json -Depth 10
} catch {
    Write-Host "[ERR] $_"
}

Write-Host ""
Write-Host "===================== BACKLOG ===================="
try {
    $bk = Invoke-RestMethod -Uri "http://localhost:5001/backlog" -TimeoutSec 10
    $bk | ConvertTo-Json -Depth 10
} catch {
    Write-Host "[ERR] $_"
}
