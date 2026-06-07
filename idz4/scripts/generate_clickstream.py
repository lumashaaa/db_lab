"""
Генератор 2 000 000 строк clickstream для events_distributed.
Запуск:
  python generate_clickstream.py | docker exec -i s1r1 clickhouse-client \
    --password click123 \
    --query "INSERT INTO events_distributed FORMAT TSV"
"""

import random
from datetime import date, datetime, timedelta

random.seed(42)

PAGES = [
    "/", "/catalog", "/product/1", "/product/2", "/cart",
    "/checkout", "/search", "/about", "/contacts", "/blog",
    "/sale", "/new", "/popular", "/profile", "/orders"
]
EVENTS = ["click", "view", "scroll", "purchase", "add_to_cart", "search"]
START = date(2024, 1, 1)

for i in range(2_000_000):
    d = START + timedelta(days=random.randint(0, 364))
    dt = datetime(d.year, d.month, d.day, random.randint(0, 23), random.randint(0, 59))
    user_id = random.randint(1, 50000)
    session = f"sess_{random.randint(1, 500000)}"
    event = random.choice(EVENTS)
    page = random.choice(PAGES)
    duration = random.randint(100, 30000)
    print(f"{d}\t{dt}\t{user_id}\t{session}\t{event}\t{page}\t{duration}")
