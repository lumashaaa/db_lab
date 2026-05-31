-- ============================================================
-- ИДЗ-1. Часть 2. Миграция 1NF → 2NF
--
-- Проблема 1NF: частичные зависимости.
-- Составной PK = (order_id, item_index).
--
-- Частичные зависимости (зависят только от order_id, не от пары):
--   order_id → order_date, customer_name, customer_email,
--              customer_phone, delivery_address, total_amount, status
--
-- Зависимости от полного ключа (order_id, item_index):
--   (order_id, item_index) → product_name, product_price, product_quantity
--
-- Решение: выделяем customers, orders, order_items.
-- Товары пока остаются inline (product_name, price_at_order).
-- ============================================================

-- ── Клиенты ──────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
    customer_id   SERIAL        PRIMARY KEY,
    name          TEXT          NOT NULL,
    email         TEXT          NOT NULL,
    phone         TEXT          NOT NULL
);

-- Уникальные клиенты (дедупликация по email + имя + телефон)
INSERT INTO customers (name, email, phone)
SELECT DISTINCT
    customer_name,
    customer_email,
    customer_phone
FROM orders_1nf
ORDER BY customer_name;

-- ── Заказы ───────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS orders CASCADE;

CREATE TABLE orders (
    order_id         INTEGER       PRIMARY KEY,
    customer_id      INTEGER       NOT NULL REFERENCES customers(customer_id),
    delivery_address TEXT          NOT NULL,
    order_date       DATE          NOT NULL,
    status           TEXT          NOT NULL,
    total_amount     NUMERIC(12,2) NOT NULL
);

INSERT INTO orders (order_id, customer_id, delivery_address, order_date, status, total_amount)
SELECT DISTINCT ON (n.order_id)
    n.order_id,
    c.customer_id,
    n.delivery_address,
    n.order_date,
    n.status,
    n.total_amount
FROM orders_1nf n
JOIN customers c
    ON  c.name  = n.customer_name
    AND c.email = n.customer_email
    AND c.phone = n.customer_phone
ORDER BY n.order_id;

-- ── Позиции заказа ───────────────────────────────────────────────────────────
-- На этапе 2NF товар ещё не вынесен в отдельную таблицу (сделаем это в 3NF).
-- Храним product_name и price_at_order прямо здесь.

DROP TABLE IF EXISTS order_items CASCADE;

CREATE TABLE order_items (
    order_id       INTEGER        NOT NULL REFERENCES orders(order_id),
    item_index     INTEGER        NOT NULL,
    product_name   TEXT           NOT NULL,
    price_at_order NUMERIC(12,2)  NOT NULL,
    quantity       INTEGER        NOT NULL,
    PRIMARY KEY (order_id, item_index)
);

INSERT INTO order_items (order_id, item_index, product_name, price_at_order, quantity)
SELECT
    order_id,
    item_index,
    product_name,
    product_price,
    product_quantity
FROM orders_1nf;

-- ── Проверка ─────────────────────────────────────────────────────────────────

SELECT 'customers'   AS table_name, COUNT(*) AS rows FROM customers
UNION ALL
SELECT 'orders',                     COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',                COUNT(*) FROM order_items;

-- Пример: заказ с позициями
SELECT
    o.order_id,
    o.order_date,
    c.name       AS customer,
    c.email,
    oi.item_index,
    oi.product_name,
    oi.price_at_order,
    oi.quantity
FROM orders o
JOIN customers  c  ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id  = o.order_id
WHERE o.order_id = 1;
