#!/bin/bash
set -e
cd "$(dirname "$0")/.."

if [ -d .git ]; then
  echo "[INFO] Repositorio git ya inicializado"
else
  git init -b main
  echo "[OK] git init"
fi

git add .
git commit -m "Tarea 2: Procesamiento y Fallback con Apache Kafka

- Generador de Trafico con Kafka Producer (Zipf y uniforme)
- Consumidores Kafka con cache y manejo de reintentos
- Generador de Respuestas con simulacion de fallas
- Sistema de Metricas (throughput, p50/p95, retry/recovery/DLQ rate, backlog)
- Topicos: queries.main, queries.retry, queries.dlq
- Docker Compose con Kafka, Zookeeper, Redis y todos los servicios" || echo "[INFO] Sin cambios para commitear"

echo ""
echo "Para subir a GitHub:"
echo "  git remote add origin <URL_DEL_REPO>"
echo "  git push -u origin main"
