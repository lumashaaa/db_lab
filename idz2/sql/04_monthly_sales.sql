CREATE TABLE IF NOT EXISTS shop.monthly_sales (
    month         Date,
    category      LowCardinality(String),
    region        LowCardinality(String),
    total_qty     UInt64,
    total_revenue Decimal(18,2)
) ENGINE = SummingMergeTree((total_qty, total_revenue))
ORDER BY (month, category, region);

INSERT INTO shop.monthly_sales
SELECT
    toStartOfMonth(order_date) AS month,
    category,
    region,
    sum(quantity)              AS total_qty,
    sum(line_total)            AS total_revenue
FROM shop.orders_flat
GROUP BY month, category, region;
