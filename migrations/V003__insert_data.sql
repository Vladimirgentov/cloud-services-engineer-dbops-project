INSERT INTO product (id, name, picture_url, price) VALUES
(1, 'Сливочная', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/6.jpg', 320.00),
(2, 'Особая', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/5.jpg', 179.00),
(3, 'Молочная', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/4.jpg', 225.00),
(4, 'Нюренбергская', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/3.jpg', 315.00),
(5, 'Мюнхенская', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/2.jpg', 330.00),
(6, 'Русская', 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/1.jpg', 189.00);

INSERT INTO orders (id, status, date_created)
SELECT
    i,
    CASE
        WHEN i % 3 = 0 THEN 'pending'
        WHEN i % 3 = 1 THEN 'shipped'
        ELSE 'cancelled'
    END,
    CURRENT_DATE - (i % 90)::int
FROM generate_series(1, 1000) AS s(i);

INSERT INTO order_product (quantity, order_id, product_id)
SELECT
    1 + (i % 50),
    i,
    1 + (i % 6)
FROM generate_series(1, 1000) AS s(i);

SELECT setval(pg_get_serial_sequence('product', 'id'), (SELECT MAX(id) FROM product));
SELECT setval(pg_get_serial_sequence('orders', 'id'), (SELECT MAX(id) FROM orders));
