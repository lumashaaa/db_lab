"""
Генератор событий для repl.events.
Запуск:
  python generate_events.py | docker exec -i node1 clickhouse-client \
    --query "INSERT INTO repl.events FORMAT TSV"
"""

import random
from datetime import datetime, timedelta

random.seed(42)

TYPES = ["click", "view", "purchase", "login", "logout"]
START = datetime(2024, 1, 1)

for i in range(100000):
    dt = START + timedelta(seconds=random.randint(0, 7776000))
    etype = random.choice(TYPES)
    uid = random.randint(1, 10000)
    payload = f"payload_{random.randint(1, 1000)}"
    print(f"{dt}\t{etype}\t{uid}\t{payload}")
