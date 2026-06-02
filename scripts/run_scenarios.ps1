param(
    [int]$WaitAfterTraffic = 30
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$resDir = Join-Path $root "resultados"
New-Item -ItemType Directory -Force -Path $resDir | Out-Null
$csv = Join-Path $resDir "scenarios.csv"

"escenario,num_consumers,dist,n_consultas,rate,failure_rate,max_retries,spike,total_eventos,throughput,p50,p95,retry_rate,dlq_rate,recovery_rate,backlog_main,backlog_retry,backlog_dlq" | Out-File -FilePath $csv -Encoding utf8

function Get-Field($obj, $name, $default = 0) {
    if ($null -eq $obj) { return $default }
    $v = $obj.$name
    if ($null -eq $v) { return $default }
    return $v
}

function Run-Scenario {
    param(
        [string]$Name,
        [int]$NC,
        [string]$Dist,
        [int]$N,
        [int]$Rate,
        [double]$FR,
        [int]$MR,
        [int]$Spike
    )

    Write-Host ""
    Write-Host "====================================================="
    Write-Host "Escenario: $Name (consumers=$NC dist=$Dist N=$N rate=$Rate fail=$FR retries=$MR spike=$Spike)"
    Write-Host "====================================================="

    docker compose down -v --remove-orphans 2>&1 | Out-Null

    $env:NUM_CONSUMERS = "$NC"
    $env:DIST = $Dist
    $env:N_CONSULTAS = "$N"
    $env:RATE = "$Rate"
    $env:FAILURE_RATE = "$FR"
    $env:MAX_RETRIES = "$MR"
    $env:SPIKE = "$Spike"

    docker compose up -d --build --scale consumidor=$NC | Out-Null

    Write-Host "[INFO] Esperando a que generador-trafico termine..."
    docker wait generador-trafico | Out-Null
    docker logs generador-trafico --tail 3

    Write-Host "[INFO] Esperando $WaitAfterTraffic s para drenar backlog..."
    Start-Sleep -Seconds $WaitAfterTraffic

    try {
        $stats = Invoke-RestMethod -Uri "http://localhost:5001/stats" -TimeoutSec 10
    } catch {
        Write-Host "[ERR] No se pudo leer /stats: $_"
        $stats = $null
    }

    try {
        $backlog = Invoke-RestMethod -Uri "http://localhost:5001/backlog" -TimeoutSec 10
    } catch {
        $backlog = $null
    }

    $total = Get-Field $stats "total_eventos" 0
    $tp = Get-Field $stats "throughput_ok_per_s" 0
    $p50 = Get-Field $stats "p50_ms" 0
    $p95 = Get-Field $stats "p95_ms" 0
    $rr = Get-Field $stats "retry_rate_pct" 0
    $dr = Get-Field $stats "dlq_rate_pct" 0
    $rc = Get-Field $stats "recovery_rate_pct" 0

    $bm = 0; $br = 0; $bd = 0
    if ($backlog) {
        $bm = Get-Field $backlog."queries.main"  "lag" 0
        $br = Get-Field $backlog."queries.retry" "lag" 0
        $bd = Get-Field $backlog."queries.dlq"   "lag" 0
    }

    "$Name,$NC,$Dist,$N,$Rate,$FR,$MR,$Spike,$total,$tp,$p50,$p95,$rr,$dr,$rc,$bm,$br,$bd" | Out-File -FilePath $csv -Encoding utf8 -Append

    Write-Host "[OK] $Name -> eventos=$total throughput=$tp p50=$p50 p95=$p95 retry=$rr% dlq=$dr% recovery=$rc%"
}

Run-Scenario -Name "kafka_1c"        -NC 1 -Dist "zipf"    -N 1000 -Rate  50 -FR 0.0 -MR 3 -Spike 0
Run-Scenario -Name "kafka_2c"        -NC 2 -Dist "zipf"    -N 1000 -Rate  50 -FR 0.0 -MR 3 -Spike 0
Run-Scenario -Name "kafka_4c"        -NC 4 -Dist "zipf"    -N 1000 -Rate  50 -FR 0.0 -MR 3 -Spike 0
Run-Scenario -Name "fallas_temp"     -NC 2 -Dist "zipf"    -N 1000 -Rate  50 -FR 0.3 -MR 3 -Spike 0
Run-Scenario -Name "spike"           -NC 2 -Dist "zipf"    -N 2000 -Rate 100 -FR 0.0 -MR 3 -Spike 1
Run-Scenario -Name "uniforme"        -NC 2 -Dist "uniform" -N 1000 -Rate  50 -FR 0.0 -MR 3 -Spike 0
Run-Scenario -Name "alta_carga"      -NC 4 -Dist "zipf"    -N 3000 -Rate 200 -FR 0.1 -MR 3 -Spike 0

Write-Host ""
Write-Host "====================================================="
Write-Host "Resultados:"
Get-Content $csv
Write-Host "====================================================="
Write-Host "CSV guardado en: $csv"
