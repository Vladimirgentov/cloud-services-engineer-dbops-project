CREATE INDEX idx_order_product_order_id ON order_product(order_id);

CREATE INDEX idx_orders_id ON orders(id);

CREATE INDEX orders_status_date_idx ON orders(status, date_created);
