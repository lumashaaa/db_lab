-- ============================================================
-- ИДЗ-1. Часть 1. Ненормализованная таблица (UNF)
-- orders_raw — «плоская» выгрузка в стиле Excel
-- ============================================================

DROP TABLE IF EXISTS orders_raw;

CREATE TABLE orders_raw (
    order_id          INTEGER,
    order_date        DATE,
    customer_name     TEXT,   -- "Иванов Иван Иванович"
    customer_email    TEXT,
    customer_phone    TEXT,
    delivery_address  TEXT,
    product_names     TEXT,   -- "Ноутбук, Мышь, Коврик"
    product_prices    TEXT,   -- "85000, 1500, 500"
    product_quantities TEXT,  -- "1, 1, 2"
    total_amount      NUMERIC,
    status            TEXT    -- "delivered"
);
