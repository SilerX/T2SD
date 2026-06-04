# Tarea 2 - Sistemas Distribuidos

## Procesamiento y Fallback con Apache Kafka (post tarea 1)

Sistema distribuido que evoluciona la arquitectura de la Tarea 1 incorporando
Apache Kafka como sistema de mensajería para procesamiento asíncrono,
reintentos automáticos y tolerancia a fallos.

## Arquitectura

```
Generador de Tráfico --> Kafka (queries.main) --> Consumidores Kafka
                                                   |--> Caché (hit) --> Métricas
                                                   |--> Generador de Respuestas (miss)
                                                          |--> OK --> Caché --> Métricas
                                                          |--> FAIL --> queries.retry
                                                                         |--> retry < max --> queries.main
                                                                         |--> retry >= max --> queries.dlq
```

## Componentes

- **kafka / zookeeper**: Cluster Kafka (Confluent Platform).
- **redis-cache**: Caché Redis con política LRU y TTL configurables.
- **generador-trafico**: Publica consultas Q1-Q5 en `queries.main`.
- **consumidor**: Lee de Kafka, consulta caché, deriva al Generador de Respuestas, maneja reintentos y DLQ.
- **generador-respuestas**: API HTTP que procesa consultas en caso de cache miss.
- **metricas**: Registra throughput, latencias, retries, recovery rate, DLQ rate y backlog.

## Tópicos Kafka

- `queries.main`: cola principal de consultas.
- `queries.retry`: cola de reintentos.
- `queries.dlq`: Dead Letter Queue.

## Política de reintentos

- `MAX_RETRIES = 3`
- Cada mensaje incluye `id`, `retry_count`, `created_at`.
- Backoff: el consumidor de retry duerme `RETRY_BACKOFF_MS` antes de reprocesar.
- Si `retry_count >= MAX_RETRIES` el mensaje se envía a `queries.dlq`.

## Configuración de caché

- Tamaño: 200 MB.
- Política: LRU (`allkeys-lru`).
- TTL: 3600 s.

## Escenarios de evaluación

Variables de entorno controlan los escenarios:

| Variable | Descripción | Default |
|---|---|---|
| `N_CONSULTAS` | Número total de consultas | 1000 |
| `DIST` | `zipf` o `uniform` | `zipf` |
| `RATE` | Consultas por segundo | 50 |
| `SPIKE` | Si vale 1 inserta un spike x10 | 0 |
| `NUM_CONSUMERS` | Réplicas de consumidor | 2 |
| `FAILURE_RATE` | Probabilidad de falla en respuestas | 0.0 |
| `MAX_RETRIES` | Máximo de reintentos | 3 |

## Cómo ejecutar

```bash
docker compose up --build
```

Para escenarios automatizados:

```bash
bash scripts/run_scenarios.sh
```

## Métricas expuestas

- Throughput (consultas/segundo)
- Latencia p50/p95
- Retry rate
- Recovery rate
- DLQ rate
- Backlog size (consumer lag)
- Recovery time
