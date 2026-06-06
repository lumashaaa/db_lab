"""
Генератор 1 000 000 строк для shop.orders_flat.
Запуск:
  python generate_data.py | docker exec -i ch1 clickhouse-client \
    --query "INSERT INTO shop.orders_flat FORMAT TSV"
"""

import random
from datetime import date, datetime, timedelta

random.seed(42)

PRODUCTS = [
    (1,  "Ноутбук ASUS VivoBook",    "Ноутбуки",              55000),
    (2,  "Ноутбук Lenovo IdeaPad",   "Ноутбуки",              45000),
    (3,  "Ноутбук HP Pavilion",      "Ноутбуки",              60000),
    (4,  "Смартфон iPhone 13",       "Смартфоны и планшеты",  75000),
    (5,  "Смартфон Samsung Galaxy",  "Смартфоны и планшеты",  35000),
    (6,  "Планшет iPad",             "Смартфоны и планшеты",  50000),
    (7,  'Монитор Dell 27"',         "Мониторы",              22000),
    (8,  "Клавиатура механическая",  "Периферия",              4500),
    (9,  "Мышь Logitech MX",         "Периферия",              3500),
    (10, "Коврик для мыши",          "Периферия",               500),
    (11, "Веб-камера Logitech",      "Периферия",              4000),
    (12, "USB-хаб 7 портов",         "Периферия",              1200),
    (13, "SSD Samsung 1TB",          "Комплектующие",          7500),
    (14, "Оперативная память 16GB",  "Комплектующие",          5000),
    (15, "Видеокарта RTX 3060",      "Комплектующие",         35000),
    (16, "Процессор Intel i5",       "Комплектующие",         18000),
    (17, "Блок питания 650W",        "Комплектующие",          5500),
    (18, "Материнская плата ASUS",   "Комплектующие",         12000),
    (19, "Корпус для ПК ATX",        "Комплектующие",          4000),
    (20, "Принтер Canon",            "Оргтехника",             8000),
    (21, "МФУ HP LaserJet",          "Оргтехника",            15000),
    (22, "Роутер TP-Link",           "Сетевое оборудование",   3000),
    (23, "Сетевой кабель 10м",       "Сетевое оборудование",    300),
    (24, "Наушники Sony WH-1000",    "Аудио",                 18000),
    (25, "Флеш-накопитель 64GB",     "Прочее",                  800),
]

REGIONS     = ["Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург",
               "Казань", "Нижний Новгород", "Самара", "Челябинск", "Омск", "Уфа"]
LAST_NAMES  = ["Иванов", "Петров", "Сидоров", "Смирнов", "Кузнецов",
               "Попов", "Лебедев", "Козлов", "Новиков", "Морозов"]
FIRST_NAMES = ["Иван", "Алексей", "Мария", "Анна", "Дмитрий",
               "Сергей", "Елена", "Ольга", "Андрей", "Наталья"]
STATUSES    = ["delivered", "delivered", "delivered", "shipped",
               "processing", "new", "cancelled"]

START = date(2023, 1, 1)
END   = date(2024, 12, 31)

for i in range(1, 1_000_001):
    d = START + timedelta(days=random.randint(0, (END - START).days))
    dt = datetime(d.year, d.month, d.day, random.randint(0, 23), random.randint(0, 59))
    cid  = random.randint(1, 50000)
    ln   = random.choice(LAST_NAMES)
    fn   = random.choice(FIRST_NAMES)
    name = f"{ln} {fn}"
    email = f"{ln.lower()}{random.randint(1,99)}@{'gmail.com' if random.random()<0.3 else 'mail.ru'}"
    region = random.choice(REGIONS)
    pid, pname, cat, base = random.choice(PRODUCTS)
    qty   = random.randint(1, 3)
    price = max(100, base + random.randint(-1000, 1000))
    total = price * qty
    status = random.choice(STATUSES)
    print(f"{d}\t{dt}\t{i}\t{cid}\t{name}\t{email}\t{region}\t"
          f"{pid}\t{pname}\t{cat}\t{qty}\t{price}\t{total}\t{status}")
