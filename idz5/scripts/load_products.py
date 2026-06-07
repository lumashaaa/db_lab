import random
import json
import time
import mysql.connector

random.seed(42)

CATEGORIES = ["Ноутбуки", "Смартфоны", "Планшеты", "Мониторы", "Наушники",
              "Клавиатуры", "Мыши", "Принтеры", "Роутеры", "Телевизоры",
              "Игровые консоли", "Фотоаппараты", "Умные часы", "Колонки"]

BRANDS = ["ASUS", "Samsung", "Apple", "Sony", "LG", "Lenovo", "HP",
          "Dell", "Xiaomi", "Huawei", "JBL", "Bose", "Logitech", "Canon"]

COLORS = ["black", "white", "silver", "blue", "red", "green", "gold"]

TITLES = [
    "Ноутбук {brand} VivoBook {n}",
    "Смартфон {brand} Galaxy {n}",
    "Беспроводные наушники {brand} QuietComfort {n}",
    "Игровая мышь {brand} Pro {n}",
    "Монитор {brand} UltraSharp {n}",
    "Планшет {brand} Tab {n}",
    "Роутер {brand} AX{n}00",
    "Принтер {brand} LaserJet {n}",
    "Умные часы {brand} Watch {n}",
    "Портативная колонка {brand} Charge {n}",
    "Механическая клавиатура {brand} Pro {n}",
    "Игровая гарнитура {brand} Nova {n}",
    "Веб-камера {brand} StreamCam {n}",
    "Внешний SSD {brand} Portable {n}TB",
]

DESCRIPTIONS = [
    "wireless bluetooth headphones with noise cancelling technology",
    "portable speaker with long battery life and waterproof design",
    "gaming laptop with high performance processor and dedicated graphics",
    "smartphone with advanced camera system and fast charging",
    "noise cancelling earbuds for immersive audio experience",
    "mechanical keyboard with rgb backlight for gaming",
    "ultrawide monitor for professional work and gaming",
    "wireless mouse with ergonomic design and long battery life",
    "tablet with high resolution display and powerful processor",
    "smart watch with health monitoring and GPS tracking",
    "laser printer for office with fast print speed",
    "wifi router with high speed and wide coverage",
    "action camera with 4k video and image stabilization",
    "portable bluetooth speaker with rich bass sound",
]

TAGS_EXTRA = ["gaming", "wireless", "portable", "professional", "budget"]

conn = mysql.connector.connect(
    host="127.0.0.1",
    port=9306,
    user="",
    password="",
    database=""
)
cursor = conn.cursor()

BATCH = 1000
total = 100000

print(f"Загружаем {total} товаров...")

for batch_start in range(0, total, BATCH):
    values = []
    for i in range(batch_start, min(batch_start + BATCH, total)):
        brand = random.choice(BRANDS)
        category = random.choice(CATEGORIES)
        title_tmpl = random.choice(TITLES)
        title = title_tmpl.format(brand=brand, n=random.randint(100, 999))
        description = random.choice(DESCRIPTIONS)
        price = round(random.uniform(500, 150000), 2)
        rating = round(random.uniform(3.0, 5.0), 1)
        reviews = random.randint(0, 5000)
        in_stock = 1 if random.random() > 0.1 else 0
        color = random.choice(COLORS)
        extra = random.choice(TAGS_EXTRA)
        tags = json.dumps({"color": color, "tag": extra, "warranty": random.randint(1, 3)})
        created_at = int(time.time()) - random.randint(0, 86400 * 365)

        values.append(
            f"('{title.replace(chr(39), chr(39)*2)}', "
            f"'{description}', '{category}', '{brand}', "
            f"{price}, {rating}, {reviews}, {in_stock}, "
            f"'{tags}', {created_at})"
        )

    sql = (
        "INSERT INTO products "
        "(title, description, category, brand, price, rating, reviews_count, in_stock, tags, created_at) "
        "VALUES " + ",".join(values)
    )
    cursor.execute(sql)

    if (batch_start + BATCH) % 10000 == 0:
        print(f"  загружено {batch_start + BATCH}...")

cursor.execute("SELECT COUNT(*) FROM products")
count = cursor.fetchone()[0]
print(f"Итого в индексе: {count}")

cursor.close()
conn.close()
