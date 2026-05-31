# ИДЗ-1. PostgreSQL: нормализация и денормализация

## Сукачева Мария, группа P4150

## Как запустить

```bash
# 1. Запустить PostgreSQL
docker run -d --name pg15 -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:15

# 2. Создать базу
docker exec -it pg15 psql -U postgres -c "CREATE DATABASE idz1;"

# 3. Запустить скрипты по порядку
docker exec pg15 psql -U postgres -d idz1 -f /idz1/sql/00_orders_raw.sql
docker exec pg15 psql -U postgres -d idz1 -f /idz1/sql/00_orders_raw_data.sql
docker exec pg15 psql -U postgres -d idz1 -f /idz1/sql/01_to_1nf.sql
docker exec pg15 psql -U postgres -d idz1 -f /idz1/sql/02_to_2nf.sql
docker exec pg15 psql -U postgres -d idz1 -f /idz1/sql/03_to_3nf.sql
docker exec pg15 psql -U postgres -d idz1 -f /idz1/sql/04_oltp_queries.sql
docker exec pg15 psql -U postgres -d idz1 -f /idz1/sql/05_indexes.sql
docker exec pg15 psql -U postgres -d idz1 -f /idz1/sql/06_denorm_mv.sql
docker exec pg15 psql -U postgres -d idz1 -f /idz1/sql/07_denorm_table.sql
```

Структура
sql/ — SQL-скрипты: UNF → 1NF → 2NF → 3NF, запросы, индексы, денормализация
checks/ — результаты EXPLAIN ANALYZE и сравнения
schema.puml — ER-диаграмма (plantuml.com)

## Аномалии таблицы orders_raw

В ненормализованной таблице три проблемы:

**Аномалия вставки** — нельзя добавить новый товар в каталог без создания заказа. Товар существует только внутри строки заказа.

**Аномалия обновления** — если клиент сменил телефон, нужно обновить его во всех строках где он встречается. Пропустишь одну — данные расходятся. В тестовых данных `серморо95@mail.ru` встречается в нескольких строках с разными телефонами.

**Аномалия удаления** — удаление единственного заказа клиента уничтожает все данные о нём: email, телефон, адрес.

---

## Итоговая схема (3NF)

```
customers   (customer_id, name, email, phone)
addresses   (address_id, customer_id → customers, address)
categories  (category_id, name)
products    (product_id, name, category_id → categories, price)
orders      (order_id, customer_id → customers, address_id → addresses, order_date, status, total_amount)
order_items (order_id → orders, item_index, product_id → products, quantity, price_at_order)
```

## OLTP vs OLAP

| | OLTP (PostgreSQL) | OLAP (ClickHouse) |
|---|---|---|
| Хранение | Строковое | Колоночное |
| Типичный запрос | Один заказ по ID | Агрегация за период |
| Нормализация | 3NF — минимум дублирования | Денормализация — широкие таблицы |
| Транзакции | Полные ACID | Ограниченные |
| Вставка | Построчная, быстрая | Пакетная |
| Обновление | Быстрое | Медленное (мутации) |
| Масштабирование | Вертикальное | Горизонтальное |
| Применение | Интернет-магазин, банк | Аналитика, BI, логи |
