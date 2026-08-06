ALTER TABLE sales
    ADD COLUMN order_date DATE NULL AFTER credit_term_days,
    ADD COLUMN delivery_date DATE NULL AFTER order_date,
    ADD COLUMN payment_terms VARCHAR(60) NULL AFTER delivery_date;

UPDATE sales
SET order_date = DATE(created_at)
WHERE order_date IS NULL;
