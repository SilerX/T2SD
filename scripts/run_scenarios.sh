#!/bin/bash
set -e

RES=resultados
mkdir -p "$RES"
CSV="$RES/scenarios.csv"
echo "escenario,num_consumers,dist,n_consultas,rate,failure_rate,max_retries,spike,throughput,p50,p95,retry_rate,dlq_rate,recovery_rate" > "$CSV"

run_one() {
  local NAME=$1; local NC=$2; local DIST=$3; local N=$4; local RATE=$5
  local FR=$6; local MR=$7; local SPIKE=$8

  echo ""
  echo "====================================================="
  echo "Escenario: $NAME"
  echo "====================================================="

  docker compose down -v 2>/dev/null || true

  export NUM_CONSUMERS=$NC
  export DIST=$DIST
  export N_CONSULTAS=$N
  export RATE=$RATE
  export FAILURE_RATE=$FR
  export MAX_RETRIES=$MR
  export SPIKE=$SPIKE

  docker compose up -d --build kafka zookeeper kafka-init redis-cache generador-respuestas metricas
  sleep 10
  docker compose up -d --scale consumidor=$NC consumidor consumidor-retry
  sleep 5
  docker compose up --abort-on-container-exit generador-trafico

  sleep 20

  STATS=$(curl -s http://localhost:5001/stats)
  TP=$(echo "$STATS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('throughput_ok_per_s',0))")
  P50=$(echo "$STATS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('p50_ms',0))")
  P95=$(echo "$STATS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('p95_ms',0))")
  RR=$(echo "$STATS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('retry_rate_pct',0))")
  DR=$(echo "$STATS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('dlq_rate_pct',0))")
  RC=$(echo "$STATS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('recovery_rate_pct',0))")

  echo "$NAME,$NC,$DIST,$N,$RATE,$FR,$MR,$SPIKE,$TP,$P50,$P95,$RR,$DR,$RC" >> "$CSV"
  echo "[OK] $NAME guardado"
}

run_one "kafka_1c"        1 zipf    1000  50 0.0  3 0
run_one "kafka_2c"        2 zipf    1000  50 0.0  3 0
run_one "kafka_4c"        4 zipf    1000  50 0.0  3 0
run_one "fallas_temp"     2 zipf    1000  50 0.3  3 0
run_one "spike"           2 zipf    2000 100 0.0  3 1
run_one "uniforme"        2 uniform 1000  50 0.0  3 0
run_one "alta_carga"      4 zipf    3000 200 0.1  3 0

echo ""
echo "====================================================="
cat "$CSV"
