UPDATE products SET price = 45000.0 WHERE id = 1;
SELECT id, title, price FROM products WHERE id = 1;

REPLACE INTO products (id, title, description, category, brand, price, rating, reviews_count, in_stock, tags, created_at)
VALUES (1, 'Ноутбук ASUS VivoBook 15 (обновлённая версия)', 'Мощный ноутбук для работы и учёбы', 'Ноутбуки', 'ASUS', 52000.0, 4.6, 312, 1, '{"color":"silver","warranty":2}', 1704067200);

DELETE FROM products WHERE id = 2;
SELECT COUNT(*) FROM products WHERE id = 2;
