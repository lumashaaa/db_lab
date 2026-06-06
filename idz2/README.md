# ИДЗ-2. ClickHouse: колоночное хранилище и OLAP-аналитика

Сукачева Мария, группа P4150

## Запуск

```bash
docker run -d --name ch1 -p 8123:8123 -p 9000:9000 clickhouse/clickhouse-server:latest

docker exec ch1 clickhouse-client --multiquery < sql/01_create_db.sql
docker exec ch1 clickhouse-client --multiquery < sql/02_orders_flat.sql
docker exec ch1 clickhouse-client --multiquery < sql/03_orders_ttl.sql
docker exec ch1 clickhouse-client --multiquery < sql/04_monthly_sales.sql

python scripts/generate_data.py | docker exec -i ch1 clickhouse-client \
  --query "INSERT INTO shop.orders_flat FORMAT TSV"

docker exec ch1 clickhouse-client --multiquery < sql/05_queries.sql
docker exec ch1 clickhouse-client --multiquery < sql/06_system_tables.sql
```

## Структура

```
sql/01_create_db.sql     — создание базы shop
sql/02_orders_flat.sql   — основная таблица MergeTree
sql/03_orders_ttl.sql    — таблица с TTL 90 дней
sql/04_monthly_sales.sql — агрегат SummingMergeTree
sql/05_queries.sql       — аналитические запросы
sql/06_system_tables.sql — статистика сжатия
config/users.xml         — пользователи default и analyst (readonly)
config/config.d/listen.xml — прослушивание 0.0.0.0
scripts/generate_data.py — генератор 1M строк
checks/                  — результаты запросов
```

## Почему денормализация в ClickHouse

В PostgreSQL данные разбиты по таблицам (3NF) — это оптимально для точечных
запросов и обновлений. В ClickHouse JOIN на лету дорогой: колоночное хранилище
читает данные столбцами, а не строками, поэтому соединять таблицы неэффективно.
Вместо этого все данные хранятся в одной плоской таблице — избыточность
компенсируется сжатием, которое в CH в 5-20 раз лучше чем в PostgreSQL.

`LowCardinality(String)` используется для полей с малым числом уникальных
значений (category, region, order_status) — внутри это словарное кодирование,
ускоряет фильтрацию и улучшает сжатие.

## Три таблицы

**orders_flat** — основное хранилище, одна строка = одна позиция заказа.
Партиционирование по месяцам (PARTITION BY toYYYYMM) ускоряет запросы за период.
ORDER BY (category, toStartOfHour(order_datetime), order_status) — данные физически
отсортированы, что улучшает сжатие и ускоряет фильтрацию по этим полям.

**orders_ttl** — то же самое, но с TTL: данные старше 90 дней удаляются
автоматически при слиянии партов (OPTIMIZE TABLE или фоновый merge).

**monthly_sales** — предагрегированные суммы по месяцу, категории и региону.
SummingMergeTree автоматически суммирует числовые поля при слиянии.
Запрос к этой таблице работает быстрее — агрегация уже посчитана.

## Почему ORDER BY влияет на сжатие

Данные физически хранятся в порядке ORDER BY. Соседние строки имеют одинаковые
значения category и order_status — LZ4/ZSTD эффективнее сжимает повторяющиеся
последовательности. LowCardinality колонки сжимаются лучше всего (ratio 10-50x),
числовые с монотонным ростом — тоже хорошо (5-20x).

## Сравнение PostgreSQL vs ClickHouse

| Операция | PostgreSQL | ClickHouse | Вывод |
|---|---|---|---|
| Вставка 1 строки | ~1 мс | ~50 мс | PG быстрее |
| Топ-10 товаров (1M строк) | ~150 мс | ~10 мс | CH быстрее в 15x |
| JOIN 4 таблиц | ~10 мс | не нужен | CH хранит данные плоско |
| Обновление статуса | ~1 мс | мутация ~сек | PG для частых UPDATE |
| Размер на диске (1M строк) | ~200 MB | ~30 MB | CH сжимает лучше |
| Поиск по подстроке | ~0.3 мс (trgm) | ~50 мс | PG с индексом быстрее |
