ALTER TABLE purchase_orders
    ADD COLUMN order_deadline DATE NULL AFTER store_id,
    ADD COLUMN expected_arrival DATE NULL AFTER order_deadline,
    ADD COLUMN purchase_representative_id BIGINT NULL AFTER expected_arrival,
    ADD COLUMN sent_at TIMESTAMP NULL AFTER approved_at;

ALTER TABLE purchase_orders
    ADD CONSTRAINT fk_purchase_orders_representative
        FOREIGN KEY (purchase_representative_id) REFERENCES users(id);

CREATE INDEX idx_purchase_orders_representative
    ON purchase_orders (purchase_representative_id);
