import os


class Config:
    REDIS_HOST = os.getenv('REDIS_HOST', 'redis-cache')
    REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))
    METRICS_KEY = os.getenv('METRICS_KEY', 'metrics:t2:events')
    KAFKA_BOOTSTRAP = os.getenv('KAFKA_BOOTSTRAP', 'kafka:9092')
    TOPIC_MAIN = os.getenv('TOPIC_MAIN', 'queries.main')
    TOPIC_RETRY = os.getenv('TOPIC_RETRY', 'queries.retry')
    TOPIC_DLQ = os.getenv('TOPIC_DLQ', 'queries.dlq')
    CONSUMER_GROUP = os.getenv('CONSUMER_GROUP', 'consumidor-grupo')
    PORT = int(os.getenv('PORT', '5001'))
