-- ============================================================
-- ИДЗ-1. Часть 5. Индексы
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- ПЕРЕД созданием индексов: сохраняем планы для сравнения
-- (вывод в файл checks/explain_before_idx.txt)
-- ─────────────────────────────────────────────────────────────

-- [ДО] Поиск по email
EXPLAIN ANALYZE
SELECT * FROM customers WHERE email = 'серморо95@mail.ru';

-- [ДО] Поиск по подстроке имени
EXPLAIN ANALYZE
SELECT * FROM customers WHERE name ILIKE '%Иванов%';

-- [ДО] Заказы клиента
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 1;

-- [ДО] Позиции по заказу
EXPLAIN ANALYZE
SELECT * FROM order_items WHERE order_id = 9;

-- [ДО] Фильтр по статусу
EXPLAIN ANALYZE
SELECT * FROM orders WHERE status = 'delivered';

-- ─────────────────────────────────────────────────────────────
-- Создание B-tree индексов
-- ─────────────────────────────────────────────────────────────

-- Уникальный индекс по email (точный поиск клиента)
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_email
    ON customers (email);

-- Индекс по customer_id в orders (JOIN + фильтр)
CREATE INDEX IF NOT EXISTS idx_orders_customer_id
    ON orders (customer_id);

-- Индекс по product_id в order_items (JOIN)
CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON order_items (product_id);

-- Индекс по status в orders (частый фильтр в OLTP-запросах)
CREATE INDEX IF NOT EXISTS idx_orders_status
    ON orders (status);

-- Индекс по order_date (диапазонные запросы, отчёты по периодам)
CREATE INDEX IF NOT EXISTS idx_orders_order_date
    ON orders (order_date);

-- Partial index: только активные (не отменённые) заказы
CREATE INDEX IF NOT EXISTS idx_orders_active
    ON orders (order_id, customer_id, order_date)
    WHERE status != 'cancelled';

-- ─────────────────────────────────────────────────────────────
-- GIN-индекс с pg_trgm для полнотекстового поиска по имени
-- ─────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GIN-индекс на имя клиента (ILIKE '%...%' станет быстрым)
CREATE INDEX IF NOT EXISTS idx_customers_name_trgm
    ON customers USING GIN (name gin_trgm_ops);

-- GIN-индекс на название товара
CREATE INDEX IF NOT EXISTS idx_products_name_trgm
    ON products USING GIN (name gin_trgm_ops);

-- ─────────────────────────────────────────────────────────────
-- ПОСЛЕ создания индексов: сохраняем планы для сравнения
-- (вывод в файл checks/explain_after_idx.txt)
-- ─────────────────────────────────────────────────────────────

-- [ПОСЛЕ] Поиск по email — теперь Index Scan вместо Seq Scan
EXPLAIN ANALYZE
SELECT * FROM customers WHERE email = 'серморо95@mail.ru';

-- [ПОСЛЕ] ILIKE по имени — теперь Bitmap Index Scan через GIN
EXPLAIN ANALYZE
SELECT * FROM customers WHERE name ILIKE '%Иванов%';

-- [ПОСЛЕ] Заказы клиента — Index Scan по idx_orders_customer_id
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 1;

-- [ПОСЛЕ] Позиции по заказу — PK-индекс уже есть
EXPLAIN ANALYZE
SELECT * FROM order_items WHERE order_id = 9;

-- [ПОСЛЕ] Фильтр по статусу — Index Scan по idx_orders_status
EXPLAIN ANALYZE
SELECT * FROM orders WHERE status = 'delivered';

-- ─────────────────────────────────────────────────────────────
-- Демонстрация: когда индекс НЕ помогает
-- ─────────────────────────────────────────────────────────────

-- LIKE '%text%' (leading wildcard) без pg_trgm → Seq Scan
-- (запрос ДО установки GIN; для воспроизведения: DROP INDEX idx_customers_name_trgm)
-- EXPLAIN ANALYZE SELECT * FROM customers WHERE name LIKE '%Иванов%';

-- Низкая селективность: status = 'delivered' покрывает ~40% строк →
-- планировщик может предпочесть Seq Scan. Раскомментировать для демонстрации:
-- SET enable_indexscan = off;
-- EXPLAIN ANALYZE SELECT * FROM orders WHERE status = 'delivered';
-- RESET enable_indexscan;

-- ─────────────────────────────────────────────────────────────
-- Итог: список всех созданных индексов
-- ─────────────────────────────────────────────────────────────

SELECT
    indexname,
    tablename,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('customers','orders','order_items','products')
ORDER BY tablename, indexname;
