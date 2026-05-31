-- ============================================================
-- ИДЗ-1. Часть 2. Миграция 2NF → 3NF
--
-- Проблема 2NF: транзитивные зависимости.
--
-- В таблице orders:
--   delivery_address зависит от customer_id, а не от order_id напрямую
--   → выносим addresses (address_id, customer_id, address)
--
-- В таблице order_items:
--   product_name → категория, текущая цена — логика о товаре, не о заказе
--   → выносим categories и products
--   → price_at_order остаётся в order_items как исторический снимок (это правильно!)
--
-- ============================================================

-- ── Категории ────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS categories CASCADE;

CREATE TABLE categories (
    category_id  SERIAL  PRIMARY KEY,
    name         TEXT    NOT NULL UNIQUE
);

-- Определяем категорию по ключевым словам в названии товара
INSERT INTO categories (name) VALUES
    ('Ноутбуки'),
    ('Смартфоны и планшеты'),
    ('Мониторы'),
    ('Периферия'),
    ('Комплектующие'),
    ('Оргтехника'),
    ('Сетевое оборудование'),
    ('Аудио'),
    ('Аксессуары'),
    ('Прочее');

-- ── Товары ───────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS products CASCADE;

CREATE TABLE products (
    product_id   SERIAL         PRIMARY KEY,
    name         TEXT           NOT NULL UNIQUE,
    category_id  INTEGER        NOT NULL REFERENCES categories(category_id),
    price        NUMERIC(12,2)  NOT NULL   -- текущая цена (может меняться)
);

-- Заполняем уникальные товары из order_items, категорию определяем эвристически
INSERT INTO products (name, category_id, price)
SELECT DISTINCT ON (product_name)
    oi.product_name,
    (
        SELECT cat.category_id FROM categories cat
        WHERE
            CASE
                WHEN oi.product_name ILIKE '%ноутбук%'                        THEN cat.name = 'Ноутбуки'
                WHEN oi.product_name ILIKE '%смартфон%'
                  OR oi.product_name ILIKE '%планшет%'
                  OR oi.product_name ILIKE '%iphone%'
                  OR oi.product_name ILIKE '%samsung galaxy%'                 THEN cat.name = 'Смартфоны и планшеты'
                WHEN oi.product_name ILIKE '%монитор%'                        THEN cat.name = 'Мониторы'
                WHEN oi.product_name ILIKE '%клавиатур%'
                  OR oi.product_name ILIKE '%мышь%'
                  OR oi.product_name ILIKE '%коврик%'
                  OR oi.product_name ILIKE '%веб-камер%'
                  OR oi.product_name ILIKE '%usb%'                            THEN cat.name = 'Периферия'
                WHEN oi.product_name ILIKE '%процессор%'
                  OR oi.product_name ILIKE '%видеокарт%'
                  OR oi.product_name ILIKE '%оперативн%'
                  OR oi.product_name ILIKE '%ssd%'
                  OR oi.product_name ILIKE '%блок питан%'
                  OR oi.product_name ILIKE '%материнск%'
                  OR oi.product_name ILIKE '%корпус%'                         THEN cat.name = 'Комплектующие'
                WHEN oi.product_name ILIKE '%принтер%'
                  OR oi.product_name ILIKE '%сканер%'
                  OR oi.product_name ILIKE '%мфу%'                            THEN cat.name = 'Оргтехника'
                WHEN oi.product_name ILIKE '%роутер%'
                  OR oi.product_name ILIKE '%кабель%'                         THEN cat.name = 'Сетевое оборудование'
                WHEN oi.product_name ILIKE '%наушник%'
                  OR oi.product_name ILIKE '%колонк%'                         THEN cat.name = 'Аудио'
                ELSE                                                               cat.name = 'Прочее'
            END
        LIMIT 1
    ),
    oi.price_at_order
FROM order_items oi
ORDER BY product_name;

-- ── Адреса клиентов ──────────────────────────────────────────────────────────

DROP TABLE IF EXISTS addresses CASCADE;

CREATE TABLE addresses (
    address_id   SERIAL   PRIMARY KEY,
    customer_id  INTEGER  NOT NULL REFERENCES customers(customer_id),
    address      TEXT     NOT NULL,
    UNIQUE (customer_id, address)
);

-- Собираем все уникальные пары (customer_id, address) из таблицы orders
INSERT INTO addresses (customer_id, address)
SELECT DISTINCT
    o.customer_id,
    o.delivery_address
FROM orders o;

-- ── Обновляем orders: заменяем delivery_address на address_id ────────────────

ALTER TABLE orders ADD COLUMN IF NOT EXISTS address_id INTEGER;

UPDATE orders o
SET address_id = a.address_id
FROM addresses a
WHERE a.customer_id = o.customer_id
  AND a.address     = o.delivery_address;

ALTER TABLE orders ALTER COLUMN address_id SET NOT NULL;
ALTER TABLE orders ADD CONSTRAINT fk_orders_address FOREIGN KEY (address_id) REFERENCES addresses(address_id);
ALTER TABLE orders DROP COLUMN delivery_address;

-- ── Обновляем order_items: заменяем product_name на product_id ───────────────

ALTER TABLE order_items ADD COLUMN IF NOT EXISTS product_id INTEGER;

UPDATE order_items oi
SET product_id = p.product_id
FROM products p
WHERE p.name = oi.product_name;

ALTER TABLE order_items ALTER COLUMN product_id SET NOT NULL;
ALTER TABLE order_items ADD CONSTRAINT fk_oi_product FOREIGN KEY (product_id) REFERENCES products(product_id);
ALTER TABLE order_items DROP COLUMN product_name;

-- ── Проверка итоговой схемы ───────────────────────────────────────────────────

SELECT 'categories'  AS table_name, COUNT(*) AS rows FROM categories
UNION ALL
SELECT 'products',                   COUNT(*) FROM products
UNION ALL
SELECT 'customers',                  COUNT(*) FROM customers
UNION ALL
SELECT 'addresses',                  COUNT(*) FROM addresses
UNION ALL
SELECT 'orders',                     COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',                COUNT(*) FROM order_items;

-- Итоговый JOIN (проверяем связность)
SELECT
    o.order_id,
    o.order_date,
    c.name       AS customer_name,
    c.email,
    a.address    AS delivery_address,
    cat.name     AS category,
    p.name       AS product,
    oi.quantity,
    oi.price_at_order,
    o.status
FROM orders o
JOIN customers   c   ON c.customer_id  = o.customer_id
JOIN addresses   a   ON a.address_id   = o.address_id
JOIN order_items oi  ON oi.order_id    = o.order_id
JOIN products    p   ON p.product_id   = oi.product_id
JOIN categories  cat ON cat.category_id = p.category_id
WHERE o.order_id = 2;
