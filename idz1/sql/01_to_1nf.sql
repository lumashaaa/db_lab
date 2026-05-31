-- ============================================================
-- ИДЗ-1. Часть 2. Миграция UNF → 1NF
--
-- Проблемы UNF, которые решаем:
--   1. product_names, product_prices, product_quantities — составные поля,
--      хранят несколько значений через запятую (нарушение атомарности).
--   2. Повторяющиеся группы: один заказ = несколько товаров в одной строке.
--
-- После 1NF:
--   Каждая строка содержит ровно один товар.
--   Составные поля разбиты. Все значения атомарны.
--   PK = (order_id, item_index).
-- ============================================================

DROP TABLE IF EXISTS orders_1nf;

CREATE TABLE orders_1nf (
    order_id          INTEGER       NOT NULL,
    item_index        INTEGER       NOT NULL,   -- порядковый номер товара в заказе (1, 2, 3...)
    order_date        DATE          NOT NULL,
    customer_name     TEXT          NOT NULL,
    customer_email    TEXT          NOT NULL,
    customer_phone    TEXT          NOT NULL,
    delivery_address  TEXT          NOT NULL,
    product_name      TEXT          NOT NULL,   -- атомарное значение (был список)
    product_price     NUMERIC(12,2) NOT NULL,   -- атомарное значение (был список)
    product_quantity  INTEGER       NOT NULL,   -- атомарное значение (был список)
    total_amount      NUMERIC(12,2) NOT NULL,
    status            TEXT          NOT NULL,
    PRIMARY KEY (order_id, item_index)
);

-- ── Миграция данных ──────────────────────────────────────────────────────────
-- Используем string_to_array + unnest + generate_subscripts для разбивки списков.
-- trim() убирает пробелы вокруг элементов.

INSERT INTO orders_1nf (
    order_id, item_index,
    order_date, customer_name, customer_email, customer_phone,
    delivery_address, product_name, product_price, product_quantity,
    total_amount, status
)
SELECT
    r.order_id,
    gs.i                                                AS item_index,
    r.order_date,
    r.customer_name,
    r.customer_email,
    r.customer_phone,
    r.delivery_address,
    trim(names.v)                                       AS product_name,
    trim(prices.v)::NUMERIC(12,2)                       AS product_price,
    trim(qtys.v)::INTEGER                               AS product_quantity,
    r.total_amount,
    r.status
FROM orders_raw r
-- Разбиваем три списка в параллельные массивы
CROSS JOIN LATERAL (
    SELECT
        string_to_array(r.product_names,     ',') AS arr_names,
        string_to_array(r.product_prices,    ',') AS arr_prices,
        string_to_array(r.product_quantities,',') AS arr_qtys
) arrays
-- Итерируемся по индексам (1-based)
CROSS JOIN LATERAL generate_subscripts(arrays.arr_names, 1) AS gs(i)
-- Вытаскиваем элемент по индексу из каждого массива
CROSS JOIN LATERAL (SELECT arrays.arr_names[gs.i])  AS names(v)
CROSS JOIN LATERAL (SELECT arrays.arr_prices[gs.i]) AS prices(v)
CROSS JOIN LATERAL (SELECT arrays.arr_qtys[gs.i])   AS qtys(v);

-- ── Проверка ─────────────────────────────────────────────────────────────────

-- Число строк в 1NF (должно быть больше, чем в orders_raw)
SELECT 'orders_raw rows' AS label, COUNT(*) FROM orders_raw
UNION ALL
SELECT '1NF rows',                  COUNT(*) FROM orders_1nf;

-- Убедимся, что составных значений больше нет
SELECT order_id, item_index, product_name, product_price, product_quantity
FROM orders_1nf
LIMIT 10;
