-- ============================================================
-- ИДЗ-1. Часть 4.1. Денормализация: материализованное представление
-- ============================================================

-- ── Создание MV ──────────────────────────────────────────────────────────────

DROP MATERIALIZED VIEW IF EXISTS mv_monthly_sales;

CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT
    date_trunc('month', o.order_date)           AS month,
    p.name                                      AS product_name,
    cat.name                                    AS category_name,
    SUM(oi.quantity)                            AS total_qty,
    SUM(oi.quantity * oi.price_at_order)        AS total_revenue
FROM order_items oi
JOIN orders     o   ON o.order_id      = oi.order_id
JOIN products   p   ON p.product_id    = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
WHERE o.status != 'cancelled'
GROUP BY 1, 2, 3
ORDER BY 1, total_revenue DESC;

-- Индекс для ускорения фильтрации по месяцу
CREATE INDEX IF NOT EXISTS idx_mv_monthly_sales_month
    ON mv_monthly_sales (month);

CREATE INDEX IF NOT EXISTS idx_mv_monthly_sales_category
    ON mv_monthly_sales (category_name);

-- ── Сравнение EXPLAIN ANALYZE: MV vs JOIN по нормализованным таблицам ────────
-- Результаты → checks/mv_vs_join.txt

-- [MV] Запрос к материализованному представлению (1 таблица, нет JOIN)
EXPLAIN ANALYZE
SELECT month, product_name, category_name, total_qty, total_revenue
FROM mv_monthly_sales
WHERE month >= '2024-01-01'::date
ORDER BY month, total_revenue DESC;

-- [JOIN] Аналогичный запрос к нормализованным таблицам (4 JOIN-а, агрегация)
EXPLAIN ANALYZE
SELECT
    date_trunc('month', o.order_date) AS month,
    p.name                            AS product_name,
    cat.name                          AS category_name,
    SUM(oi.quantity)                  AS total_qty,
    SUM(oi.quantity * oi.price_at_order) AS total_revenue
FROM order_items oi
JOIN orders     o   ON o.order_id      = oi.order_id
JOIN products   p   ON p.product_id    = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
WHERE o.status    != 'cancelled'
  AND o.order_date >= '2024-01-01'
GROUP BY 1, 2, 3
ORDER BY 1, total_revenue DESC;

-- ── Обновление MV ────────────────────────────────────────────────────────────
-- MV не обновляется автоматически при изменении базовых таблиц.
-- Стратегии:
--   1. Ручное:  REFRESH MATERIALIZED VIEW mv_monthly_sales;
--   2. CONCURRENTLY (без блокировки чтения, требует UNIQUE-индекс):
--      REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;
--   3. Через pg_cron (расписание, например, раз в час или раз в сутки).

-- Для CONCURRENTLY нужен уникальный составной индекс:
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_monthly_sales_unique
    ON mv_monthly_sales (month, product_name, category_name);

-- Пример обновления (без CONCURRENTLY, т.к. выполняется единожды при миграции):
REFRESH MATERIALIZED VIEW mv_monthly_sales;

-- ── Дополнительные отчётные запросы на базе MV ───────────────────────────────

-- Топ-5 категорий по выручке за 2024 год
SELECT
    category_name,
    SUM(total_revenue) AS annual_revenue,
    SUM(total_qty)     AS annual_qty
FROM mv_monthly_sales
WHERE month >= '2024-01-01' AND month < '2025-01-01'
GROUP BY category_name
ORDER BY annual_revenue DESC
LIMIT 5;

-- Динамика продаж по месяцам
SELECT
    month,
    SUM(total_revenue) AS monthly_revenue
FROM mv_monthly_sales
GROUP BY month
ORDER BY month;
