-- ============================================================
-- ИДЗ-1. Часть 3. OLTP-запросы
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 3.1. Создание заказа — транзакция с SELECT ... FOR UPDATE
--      и CTE + RETURNING
-- ─────────────────────────────────────────────────────────────

BEGIN;

-- Шаг 1: убеждаемся, что клиент существует (блокируем строку)
SELECT customer_id, name, email
FROM customers
WHERE email = 'серморо95@mail.ru'
FOR UPDATE;

-- Шаг 2: вставляем заказ через CTE с RETURNING
WITH new_order AS (
    INSERT INTO orders (order_id, customer_id, address_id, order_date, status, total_amount)
    SELECT
        (SELECT COALESCE(MAX(order_id), 0) + 1 FROM orders),  -- следующий ID
        c.customer_id,
        a.address_id,
        CURRENT_DATE,
        'new',
        0  -- пересчитаем после вставки позиций
    FROM customers c
    JOIN addresses a ON a.customer_id = c.customer_id
    WHERE c.email = 'серморо95@mail.ru'
    LIMIT 1
    RETURNING order_id, customer_id
),
new_items AS (
    INSERT INTO order_items (order_id, item_index, product_id, price_at_order, quantity)
    SELECT
        no.order_id,
        gs.i,
        p.product_id,
        p.price,
        1
    FROM new_order no
    CROSS JOIN (VALUES (1, 'Мышь Logitech MX'), (2, 'Коврик для мыши')) AS items(i, pname)
    CROSS JOIN LATERAL (
        SELECT product_id, price FROM products
        WHERE name = items.pname
        LIMIT 1
    ) p
    CROSS JOIN LATERAL (SELECT items.i) AS gs(i)
    RETURNING order_id, product_id, price_at_order, quantity
)
-- Шаг 3: обновляем total_amount
UPDATE orders
SET total_amount = (
    SELECT SUM(price_at_order * quantity)
    FROM new_items
    WHERE new_items.order_id = orders.order_id
)
WHERE order_id = (SELECT order_id FROM new_order);

COMMIT;

-- ─────────────────────────────────────────────────────────────
-- 3.2. Обновление статуса заказа
-- ─────────────────────────────────────────────────────────────

UPDATE orders
SET status = 'shipped'
WHERE order_id = 5
  AND status   = 'processing'
RETURNING order_id, status;

-- ─────────────────────────────────────────────────────────────
-- 3.3. Получение полной информации о заказе
--      JOIN по 5 таблицам: orders + customers + addresses + order_items + products
-- ─────────────────────────────────────────────────────────────

SELECT
    o.order_id,
    o.order_date,
    o.status,
    o.total_amount,
    -- клиент
    c.name          AS customer_name,
    c.email         AS customer_email,
    c.phone         AS customer_phone,
    -- адрес доставки
    a.address       AS delivery_address,
    -- позиции
    oi.item_index,
    p.name          AS product_name,
    cat.name        AS category,
    oi.quantity,
    oi.price_at_order,
    oi.quantity * oi.price_at_order AS line_total
FROM orders o
JOIN customers   c   ON c.customer_id   = o.customer_id
JOIN addresses   a   ON a.address_id    = o.address_id
JOIN order_items oi  ON oi.order_id     = o.order_id
JOIN products    p   ON p.product_id    = oi.product_id
JOIN categories  cat ON cat.category_id = p.category_id
WHERE o.order_id = 9
ORDER BY oi.item_index;

EXPLAIN ANALYZE
SELECT
    o.order_id, o.order_date, o.status, o.total_amount,
    c.name, c.email, a.address,
    p.name AS product_name, oi.quantity, oi.price_at_order
FROM orders o
JOIN customers   c   ON c.customer_id   = o.customer_id
JOIN addresses   a   ON a.address_id    = o.address_id
JOIN order_items oi  ON oi.order_id     = o.order_id
JOIN products    p   ON p.product_id    = oi.product_id
WHERE o.order_id = 9;

-- ─────────────────────────────────────────────────────────────
-- 3.4. Отчёт «Топ-10 товаров» по выручке
-- ─────────────────────────────────────────────────────────────

SELECT
    p.name                                    AS product_name,
    cat.name                                  AS category,
    SUM(oi.quantity)                          AS total_qty,
    SUM(oi.quantity * oi.price_at_order)      AS total_revenue
FROM order_items oi
JOIN products   p   ON p.product_id    = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
JOIN orders     o   ON o.order_id      = oi.order_id
WHERE o.status != 'cancelled'
GROUP BY p.product_id, p.name, cat.name
ORDER BY total_revenue DESC
LIMIT 10;

EXPLAIN ANALYZE
SELECT p.name, SUM(oi.quantity * oi.price_at_order) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders   o ON o.order_id   = oi.order_id
WHERE o.status != 'cancelled'
GROUP BY p.product_id, p.name
ORDER BY revenue DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────
-- 3.5a. Поиск клиента по email (точное совпадение, использует B-tree индекс)
-- ─────────────────────────────────────────────────────────────

EXPLAIN ANALYZE
SELECT customer_id, name, email, phone
FROM customers
WHERE email = 'серморо95@mail.ru';

-- ─────────────────────────────────────────────────────────────
-- 3.5b. Поиск клиента по подстроке имени (ILIKE — полное сканирование без trgm)
-- ─────────────────────────────────────────────────────────────

EXPLAIN ANALYZE
SELECT customer_id, name, email, phone
FROM customers
WHERE name ILIKE '%Иванов%';
