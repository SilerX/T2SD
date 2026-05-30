import json
import time
from kafka import KafkaConsumer
from kafka.errors import NoBrokersAvailable


class QueryConsumer:
    def __init__(self, bootstrap_servers, topic, group_id, handler, backoff_ms=0):
        self.topic = topic
        self.group_id = group_id
        self.handler = handler
        self.backoff_ms = backoff_ms
        self.consumer = self._connect(bootstrap_servers)

    def _connect(self, bootstrap, max_retries=30):
        for i in range(max_retries):
            try:
                c = KafkaConsumer(
                    self.topic,
                    bootstrap_servers=bootstrap,
                    group_id=self.group_id,
                    auto_offset_reset='earliest',
                    enable_auto_commit=True,
                    value_deserializer=lambda v: json.loads(v.decode('utf-8')),
                    key_deserializer=lambda k: k.decode('utf-8') if k else None,
                    consumer_timeout_ms=0,
                    max_poll_records=10,
                )
                print(f"[OK] Consumer suscrito al topic '{self.topic}' (grupo='{self.group_id}')")
                return c
            except NoBrokersAvailable:
                print(f"[..] Esperando Kafka para consumer (intento {i+1}/{max_retries})")
                time.sleep(2)
        raise RuntimeError("Consumer no pudo conectar a Kafka")

    def run(self):
        try:
            for msg in self.consumer:
                if self.backoff_ms > 0:
                    time.sleep(self.backoff_ms / 1000.0)
                try:
                    self.handler.handle(msg.value)
                except Exception as e:
                    print(f"[ERR] handler fail: {type(e).__name__}: {e}")
        except KeyboardInterrupt:
            print("[INFO] Consumer detenido por usuario")
        finally:
            self.consumer.close()
