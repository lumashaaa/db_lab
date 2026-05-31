-- ============================================================
-- ИДЗ-1. Часть 4.2. Денормализация в таблицу: избыточные поля
-- ============================================================

-- ── 4.2a. orders.customer_name — избыточное текстовое поле ───────────────────
--
-- ЗАЧЕМ:
--   Имя клиента на момент оформления заказа фиксируется как исторический снимок.
--   Если клиент позже изменит ФИО в профиле — факт заказа останется корректным.
--   Ускоряет запросы «последние 20 заказов с именем клиента» — нет JOIN с customers.
--
-- ЦЕНА:
--   Аномалия обновления: если имя меняется, поле в orders не обновится само.
--   Синхронизация через триггер или прикладной код.
--
-- ОПРАВДАНО КОГДА:
--   Нужен неизменяемый аудит-лог (заказ = документ, ФИО фиксируется навсегда).
--   Отчёты с высокой частотой чтения без возможности кэшировать.
--
-- НЕ ОПРАВДАНО КОГДА:
--   Нужна актуальная информация о клиенте (используйте JOIN).
--   Размер таблицы заказов очень большой (дублирование раздувает хранилище).

ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_name TEXT;

-- Заполняем исторически (на момент миграции)
UPDATE orders o
SET customer_name = c.name
FROM customers c
WHERE c.customer_id = o.customer_id;

-- Индекс для поиска заказов по имени клиента (OLTP-запрос типа «заказы Иванова»)
CREATE INDEX IF NOT EXISTS idx_orders_customer_name
    ON orders (customer_name);

-- ── Триггер для синхронизации customer_name при изменении customers.name ──────

CREATE OR REPLACE FUNCTION trg_sync_order_customer_name()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Обновляем только если имя действительно изменилось
    IF NEW.name IS DISTINCT FROM OLD.name THEN
        UPDATE orders
        SET customer_name = NEW.name
        WHERE customer_id = NEW.customer_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_customers_name_change ON customers;
CREATE TRIGGER trg_customers_name_change
AFTER UPDATE OF name ON customers
FOR EACH ROW EXECUTE FUNCTION trg_sync_order_customer_name();

-- ── 4.2b. order_items.product_name — снимок названия товара ──────────────────
--
-- ЗАЧЕМ:
--   Название товара может измениться (ребрендинг, уточнение модели).
--   В истории заказов клиент должен видеть то название, которое было при покупке.
--   Это стандартная практика интернет-магазинов (как цена в price_at_order).
--
-- ЦЕНА:
--   Дублирование данных. Однако поле НЕ синхронизируется — это намеренно,
--   поскольку является историческим снимком, а не актуальной ссылкой.

ALTER TABLE order_items ADD COLUMN IF NOT EXISTS product_name_snapshot TEXT;

UPDATE order_items oi
SET product_name_snapshot = p.name
FROM products p
WHERE p.product_id = oi.product_id;

-- ── Сравнение: запрос С денормализацией vs БЕЗ ───────────────────────────────

-- БЕЗ денормализации (нужен JOIN)
EXPLAIN ANALYZE
SELECT o.order_id, o.order_date, c.name AS customer, p.name AS product
FROM orders o
JOIN customers   c  ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN products    p  ON p.product_id  = oi.product_id
WHERE o.order_id BETWEEN 1 AND 50;

-- С денормализацией (нет JOIN с customers и products)
EXPLAIN ANALYZE
SELECT o.order_id, o.order_date, o.customer_name, oi.product_name_snapshot
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_id BETWEEN 1 AND 50;

-- ── Итоговый вывод о денормализации ──────────────────────────────────────────
-- Материализованное представление (06_denorm_mv.sql):
--   + Полностью автоматический расчёт агрегатов
--   + Не меняет основную схему
--   - Данные устаревают до следующего REFRESH
--   → Лучший выбор для OLAP-отчётов, дашбордов, BI
--
-- Избыточные поля в таблицах (этот файл):
--   + Мгновенный доступ без JOIN, читается в одном скане
--   + Исторический снимок — правильная семантика для аудита
--   - Требуют поддержки (триггер или логика в приложении)
--   → Лучший выбор для аудит-логов, горячих путей чтения
