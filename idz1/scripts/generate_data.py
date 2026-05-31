#!/usr/bin/env python3
"""
Генератор тестовых данных для orders_raw.
Создаёт файл sql/00_orders_raw_data.sql с >= 1000 строками INSERT.
"""

import random
from datetime import date, timedelta

# ── Справочники ──────────────────────────────────────────────────────────────

FIRST_NAMES = [
    "Александр", "Дмитрий", "Максим", "Сергей", "Андрей",
    "Алексей", "Артём", "Илья", "Кирилл", "Михаил",
    "Анна", "Мария", "Елена", "Ольга", "Татьяна",
    "Наталья", "Ирина", "Светлана", "Юлия", "Екатерина",
]
LAST_NAMES = [
    "Иванов", "Смирнов", "Кузнецов", "Попов", "Васильев",
    "Петров", "Соколов", "Михайлов", "Новиков", "Фёдоров",
    "Морозов", "Волков", "Алексеев", "Лебедев", "Семёнов",
]
PATRONYMICS = [
    "Александрович", "Дмитриевич", "Сергеевич", "Андреевич",
    "Алексеевич", "Михайлович", "Николаевич", "Владимирович",
    "Александровна", "Дмитриевна", "Сергеевна", "Андреевна",
]
EMAIL_DOMAINS = ["gmail.com", "yandex.ru", "mail.ru", "outlook.com", "rambler.ru"]

CITIES = [
    "Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург", "Казань",
    "Нижний Новгород", "Челябинск", "Самара", "Уфа", "Ростов-на-Дону",
]
STREETS = [
    "ул. Ленина", "пр. Мира", "ул. Гагарина", "ул. Пушкина",
    "ул. Садовая", "пр. Победы", "ул. Советская", "ул. Кирова",
]

PRODUCTS = [
    ("Ноутбук Lenovo IdeaPad",   45000),
    ("Ноутбук ASUS VivoBook",    55000),
    ("Ноутбук HP Pavilion",      60000),
    ("Смартфон Samsung Galaxy",  35000),
    ("Смартфон iPhone 13",       75000),
    ("Планшет iPad",             50000),
    ("Монитор Dell 27\"",        22000),
    ("Клавиатура механическая",   4500),
    ("Мышь Logitech MX",         3500),
    ("Коврик для мыши",            500),
    ("Наушники Sony WH-1000",    18000),
    ("Веб-камера Logitech",       4000),
    ("USB-хаб 7 портов",         1200),
    ("SSD Samsung 1TB",           7500),
    ("Оперативная память 16GB",   5000),
    ("Видеокарта RTX 3060",      35000),
    ("Процессор Intel i5",       18000),
    ("Материнская плата ASUS",   12000),
    ("Блок питания 650W",         5500),
    ("Корпус для ПК ATX",         4000),
    ("Принтер Canon",             8000),
    ("МФУ HP LaserJet",          15000),
    ("Роутер TP-Link",            3000),
    ("Сетевой кабель 10м",         300),
    ("Флеш-накопитель 64GB",       800),
]

STATUSES = ["pending", "processing", "shipped", "delivered", "cancelled"]
STATUS_WEIGHTS = [0.05, 0.10, 0.15, 0.55, 0.15]

# ── Вспомогательные функции ──────────────────────────────────────────────────

def random_date(start: date, end: date) -> date:
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

def random_phone() -> str:
    return "+7" + "".join([str(random.randint(0, 9)) for _ in range(10)])

def escape(s: str) -> str:
    return s.replace("'", "''")

# ── Генерация строк ──────────────────────────────────────────────────────────

def generate_rows(n: int = 1200) -> list[dict]:
    rows = []
    start_date = date(2023, 1, 1)
    end_date   = date(2024, 12, 31)

    for order_id in range(1, n + 1):
        # Клиент
        last  = random.choice(LAST_NAMES)
        first = random.choice(FIRST_NAMES)
        patr  = random.choice(PATRONYMICS)
        full_name = f"{last} {first} {patr}"
        email_local = (first[:3] + last[:4]).lower()
        email = f"{email_local}{random.randint(1, 99)}@{random.choice(EMAIL_DOMAINS)}"
        phone = random_phone()

        # Адрес
        city   = random.choice(CITIES)
        street = random.choice(STREETS)
        house  = random.randint(1, 150)
        apt    = random.randint(1, 300)
        address = f"{city}, {street}, д.{house}, кв.{apt}"

        # Товары (1–4 позиции)
        num_items = random.randint(1, 4)
        chosen = random.sample(PRODUCTS, num_items)
        names      = ", ".join(p[0] for p in chosen)
        prices     = ", ".join(str(p[1]) for p in chosen)
        quantities = []
        total = 0
        for p in chosen:
            q = random.randint(1, 3)
            quantities.append(str(q))
            total += p[1] * q
        qtys_str = ", ".join(quantities)

        # Дата и статус
        order_date = random_date(start_date, end_date)
        status = random.choices(STATUSES, STATUS_WEIGHTS)[0]

        rows.append({
            "order_id":          order_id,
            "order_date":        order_date.isoformat(),
            "customer_name":     escape(full_name),
            "customer_email":    escape(email),
            "customer_phone":    phone,
            "delivery_address":  escape(address),
            "product_names":     escape(names),
            "product_prices":    prices,
            "product_quantities": qtys_str,
            "total_amount":      total,
            "status":            status,
        })
    return rows

# ── Запись SQL ───────────────────────────────────────────────────────────────

def write_sql(rows: list[dict], path: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- Автоматически сгенерированные тестовые данные для orders_raw\n")
        f.write(f"-- Строк: {len(rows)}\n\n")
        f.write("INSERT INTO orders_raw (\n")
        f.write("    order_id, order_date, customer_name, customer_email, customer_phone,\n")
        f.write("    delivery_address, product_names, product_prices, product_quantities,\n")
        f.write("    total_amount, status\n")
        f.write(") VALUES\n")

        value_lines = []
        for r in rows:
            line = (
                f"    ({r['order_id']}, '{r['order_date']}', "
                f"'{r['customer_name']}', '{r['customer_email']}', '{r['customer_phone']}', "
                f"'{r['delivery_address']}', '{r['product_names']}', '{r['product_prices']}', "
                f"'{r['product_quantities']}', {r['total_amount']}, '{r['status']}')"
            )
            value_lines.append(line)

        f.write(",\n".join(value_lines))
        f.write(";\n")

    print(f"Записано {len(rows)} строк → {path}")

# ── main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import os
    random.seed(42)
    rows = generate_rows(1200)
    out_path = os.path.join(os.path.dirname(__file__), "..", "sql", "00_orders_raw_data.sql")
    out_path = os.path.normpath(out_path)
    write_sql(rows, out_path)
