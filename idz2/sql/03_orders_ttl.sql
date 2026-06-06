CREATE TABLE IF NOT EXISTS shop.orders_ttl (
    order_date       Date,
    order_datetime   DateTime,
    order_id         UInt64,
    customer_id      UInt64,
    customer_name    String,
    customer_email   LowCardinality(String),
    region           LowCardinality(String),
    product_id       UInt64,
    product_name     String,
    category         LowCardinality(String),
    quantity         UInt32,
    price            Decimal(12,2),
    line_total       Decimal(12,2),
    order_status     LowCardinality(String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(order_date)
ORDER BY (category, toStartOfHour(order_datetime), order_status)
TTL order_date + INTERVAL 90 DAY DELETE;

INSERT INTO shop.orders_ttl SELECT * FROM shop.orders_flat WHERE order_date < today() - 90 LIMIT 1000;

SELECT partition, name, rows, active, formatReadableSize(bytes_on_disk) AS size
FROM system.parts
WHERE table = 'orders_ttl' AND database = 'shop'
ORDER BY partition;

OPTIMIZE TABLE shop.orders_ttl FINAL;

SELECT partition, name, rows, active, formatReadableSize(bytes_on_disk) AS size
FROM system.parts
WHERE table = 'orders_ttl' AND database = 'shop'
ORDER BY partition;
