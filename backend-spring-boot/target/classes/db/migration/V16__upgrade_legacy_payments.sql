-- Upgrade legacy payments table to support cart-based payment fields

ALTER TABLE payments
    MODIFY sale_id BIGINT NULL,
    ADD COLUMN cart_id BIGINT NULL,
    ADD COLUMN customer_id BIGINT NULL,
    ADD COLUMN store_id BIGINT NULL,
    ADD COLUMN currency VARCHAR(3) DEFAULT 'USD',
    ADD COLUMN payment_method VARCHAR(50) NULL,
    ADD COLUMN transaction_id VARCHAR(255) NULL,
    ADD COLUMN reference_number VARCHAR(255) NULL,
    ADD COLUMN error_message TEXT NULL,
    ADD COLUMN notes TEXT NULL,
    ADD COLUMN created_by VARCHAR(100) NULL,
    ADD COLUMN updated_by VARCHAR(100) NULL,
    ADD COLUMN updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;
