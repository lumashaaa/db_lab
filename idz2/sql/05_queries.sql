SELECT
    product_name,
    category,
    sum(quantity)   AS total_qty,
    sum(line_total) AS total_revenue
FROM shop.orders_flat
WHERE order_status != 'cancelled'
GROUP BY product_name, category
ORDER BY total_revenue DESC
LIMIT 10;

SELECT
    toStartOfMonth(order_date) AS month,
    category,
    sum(quantity)              AS total_qty,
    sum(line_total)            AS total_revenue
FROM shop.orders_flat
WHERE order_status != 'cancelled'
GROUP BY month, category
ORDER BY month, total_revenue DESC;

SELECT
    quantile(0.95)(line_total) AS p95,
    quantile(0.99)(line_total) AS p99,
    max(line_total)            AS max_val,
    avg(line_total)            AS avg_val
FROM shop.orders_flat
WHERE order_status != 'cancelled';

SELECT DISTINCT customer_id, customer_name, customer_email
FROM shop.orders_flat
WHERE customer_email LIKE '%gmail%'
LIMIT 10;

SELECT toStartOfMonth(order_date) AS month, category,
    sum(quantity) AS qty, sum(line_total) AS revenue
FROM shop.orders_flat
WHERE order_status != 'cancelled'
GROUP BY month, category
ORDER BY month, category
LIMIT 20;

SELECT month, category, sum(total_qty) AS qty, sum(total_revenue) AS revenue
FROM shop.monthly_sales
GROUP BY month, category
ORDER BY month, category
LIMIT 20;
