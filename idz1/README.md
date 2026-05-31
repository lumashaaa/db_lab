# ИДЗ-1. PostgreSQL: структуры данных, нормализация и денормализация

**Студент:** Сукачева Мария, группа P4150, 1 курс магистратуры  
**Предметная область:** интернет-магазин (заказы, товары, клиенты, категории)

---

## Структура репозитория

```
idz1/
├── README.md
├── schema.puml                  # ER-диаграмма итоговой 3NF-схемы
├── sql/
│   ├── 00_orders_raw.sql        # UNF: DDL таблицы
│   ├── 00_orders_raw_data.sql   # UNF: 1200 строк INSERT (генерируется скриптом)
│   ├── 01_to_1nf.sql            # Миграция UNF → 1NF
│   ├── 02_to_2nf.sql            # Миграция 1NF → 2NF
│   ├── 03_to_3nf.sql            # Миграция 2NF → 3NF
│   ├── 04_oltp_queries.sql      # OLTP-запросы с EXPLAIN ANALYZE
│   ├── 05_indexes.sql           # Создание индексов + сравнение до/после
│   ├── 06_denorm_mv.sql         # Материализованное представление
│   └── 07_denorm_table.sql      # Денормализация в таблицу (избыточные поля)
├── scripts/
│   └── generate_data.py         # Генератор тестовых данных (1200 строк)
└── checks/
    ├── anomalies.txt            # Примеры аномалий UNF с данными
    ├── explain_before_idx.txt   # EXPLAIN до создания индексов
    ├── explain_after_idx.txt    # EXPLAIN после создания индексов
    ├── mv_vs_join.txt           # Сравнение MV и JOIN
    └── trgm_demo.txt            # Демонстрация pg_trgm
```

---

## Часть 1. Аномалии таблицы orders_raw (UNF)

Подробные примеры с реальными данными: [`checks/anomalies.txt`](checks/anomalies.txt)

### Аномалия вставки
Невозможно добавить товар в каталог без создания заказа. Информация о товаре
существует только в контексте строки заказа — нет отдельной таблицы товаров.  
**Пример:** «Игровой монитор 240Гц» нельзя внести в систему до первой продажи.

### Аномалия обновления
Данные клиента дублируются в каждой строке заказа. Изменение телефона требует
UPDATE во всех строках — при пропуске хотя бы одной данные становятся
несогласованными.  
**Пример:** `серморо95@mail.ru` встречается в строках 1 и 10 с _разными_ телефонами.

### Аномалия удаления
Удаление единственного заказа клиента уничтожает все данные о нём (email, телефон).
Аналогично — удаление строки с единственным упоминанием товара удаляет товар.  
**Пример:** удаление `order_id = 3` уничтожает данные о клиенте `екалебе74@yandex.ru`.

---

## Часть 2. Нормализация

### UNF → 1NF (`01_to_1nf.sql`)
**Проблема:** поля `product_names`, `product_prices`, `product_quantities` содержат
несколько значений через запятую — нарушение атомарности.

**Решение:** `unnest` + `generate_subscripts` разбивают каждую строку на N строк
(по числу товаров в заказе). PK становится `(order_id, item_index)`.

### 1NF → 2NF (`02_to_2nf.sql`)
**Проблема:** частичные зависимости от составного PK `(order_id, item_index)`.  
`order_date`, `customer_name`, `delivery_address` зависят только от `order_id`.

**Решение:** выделяем `customers` и `orders` (данные, зависящие только от `order_id`);
позиции заказа остаются в `order_items`.

### 2NF → 3NF (`03_to_3nf.sql`)
**Проблема:** транзитивные зависимости.
- В `orders`: `delivery_address` транзитивно зависит от `customer_id`.
- В `order_items`: `product_name` → категория, текущая цена — не зависит от заказа.

**Решение:** выделяем `addresses`, `products`, `categories`.
`price_at_order` остаётся в `order_items` — это исторический снимок цены (правильно).

### Итоговая схема 3NF

```
customers    (customer_id PK, name, email UNIQUE, phone)
addresses    (address_id PK, customer_id FK, address)
categories   (category_id PK, name UNIQUE)
products     (product_id PK, name UNIQUE, category_id FK, price)
orders       (order_id PK, customer_id FK, address_id FK, order_date, status, total_amount)
order_items  (order_id FK PK, item_index PK, product_id FK, quantity, price_at_order)
```

ER-диаграмма: [`schema.puml`](schema.puml)

---

## Часть 4. Денормализация

### 4.1. Материализованное представление (`06_denorm_mv.sql`)
`mv_monthly_sales` агрегирует продажи по месяцу, товару и категории.  
**Сравнение:** запрос к MV ~1 мс vs 4-JOIN запрос ~10 мс (подробнее: [`checks/mv_vs_join.txt`](checks/mv_vs_join.txt)).  
**Обновление:** `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales`.

### 4.2. Избыточные поля (`07_denorm_table.sql`)

| Поле | Зачем | Цена |
|------|-------|------|
| `orders.customer_name` | Исторический снимок ФИО; ускорение чтения без JOIN | Триггер для синхронизации при смене имени |
| `order_items.product_name_snapshot` | Снимок названия товара при покупке | Намеренно не синхронизируется (аудит) |

**Оправдано:** аудит-логи, горячие пути чтения, высокая нагрузка на чтение.  
**Не оправдано:** актуальные данные нужны в реальном времени, таблица очень большая.

---

## Часть 5. Индексы

| Индекс | Тип | Таблица | Поле | Зачем |
|--------|-----|---------|------|-------|
| `idx_customers_email` | B-tree UNIQUE | customers | email | Точный поиск клиента |
| `idx_orders_customer_id` | B-tree | orders | customer_id | JOIN, фильтр |
| `idx_order_items_product_id` | B-tree | order_items | product_id | JOIN |
| `idx_orders_status` | B-tree | orders | status | Фильтр по статусу |
| `idx_orders_order_date` | B-tree | orders | order_date | Диапазонные запросы |
| `idx_orders_active` | B-tree Partial | orders | — | WHERE status != 'cancelled' |
| `idx_customers_name_trgm` | GIN (pg_trgm) | customers | name | ILIKE '%...%' |
| `idx_products_name_trgm` | GIN (pg_trgm) | products | name | ILIKE '%...%' |

Сравнение до/после: [`checks/explain_before_idx.txt`](checks/explain_before_idx.txt),
[`checks/explain_after_idx.txt`](checks/explain_after_idx.txt)

pg_trgm демонстрация: [`checks/trgm_demo.txt`](checks/trgm_demo.txt)

---

## Часть 6. OLTP vs OLAP

| Характеристика | OLTP (PostgreSQL) | OLAP (ClickHouse) |
|---|---|---|
| **Модель хранения** | Строковая (row-oriented) | Колоночная (column-oriented) |
| **Типичный запрос** | `SELECT * FROM orders WHERE order_id = 5` — точечное чтение/запись одной или нескольких строк | `SELECT product, SUM(revenue) FROM sales GROUP BY product` — агрегация по миллионам строк |
| **Нормализация** | 3NF и выше: минимальная избыточность, легко обновлять | Денормализованные wide-таблицы / star/snowflake схемы; JOIN-ы дорогие |
| **Транзакции** | Полноценные ACID-транзакции (BEGIN/COMMIT, ROLLBACK, MVCC) | Ограниченная поддержка; INSERT атомарен, но UPDATE/DELETE дорогие и нежелательны |
| **Вставка** | Построчная, быстрая (`INSERT INTO ... VALUES`), поддержка `RETURNING` | Пакетная (batched): вставка тысяч строк за раз эффективна; одиночные INSERT — неэффективны |
| **Обновление/удаление** | Эффективны: UPDATE/DELETE по индексу; MVCC обеспечивает изоляцию | Медленные и нежелательны: ClickHouse использует мутации (`ALTER TABLE ... UPDATE/DELETE`), не предназначен для частых изменений |
| **Масштабирование** | Вертикальное (более мощный сервер) + read-реплики; шардирование сложно | Горизонтальное (кластер из дешёвых серверов); встроенная репликация и шардирование |
| **Типичный use case** | Интернет-магазин: оформление заказов, управление остатками, работа с клиентами | Аналитика продаж, BI-дашборды, обработка логов, отчёты за период |

---

## Запуск

```bash
# 1. Поднять PostgreSQL
docker run -d --name pg15 -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:15

# 2. Создать БД
psql -h localhost -U postgres -c "CREATE DATABASE idz1;"

# 3. Выполнить миграции последовательно
psql -h localhost -U postgres -d idz1 -f sql/00_orders_raw.sql
psql -h localhost -U postgres -d idz1 -f sql/00_orders_raw_data.sql
psql -h localhost -U postgres -d idz1 -f sql/01_to_1nf.sql
psql -h localhost -U postgres -d idz1 -f sql/02_to_2nf.sql
psql -h localhost -U postgres -d idz1 -f sql/03_to_3nf.sql
psql -h localhost -U postgres -d idz1 -f sql/04_oltp_queries.sql
psql -h localhost -U postgres -d idz1 -f sql/05_indexes.sql
psql -h localhost -U postgres -d idz1 -f sql/06_denorm_mv.sql
psql -h localhost -U postgres -d idz1 -f sql/07_denorm_table.sql

# Или — регенерировать данные вручную:
python scripts/generate_data.py > sql/00_orders_raw_data.sql
```

---

## Коммиты

```
feat(idz1): add UNF table orders_raw with 1200 test rows
feat(idz1): normalize to 1NF — split composite product fields via unnest
feat(idz1): normalize to 2NF — extract customers, orders, order_items
feat(idz1): normalize to 3NF — extract categories, products, addresses
feat(idz1): add OLTP queries with transactions and EXPLAIN ANALYZE
feat(idz1): add B-tree and GIN/trgm indexes with before/after comparison
feat(idz1): add denormalization — materialized view and redundant fields
docs(idz1): add README with anomalies, OLTP vs OLAP table, schema
```
