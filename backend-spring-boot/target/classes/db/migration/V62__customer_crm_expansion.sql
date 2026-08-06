ALTER TABLE customers
    ADD COLUMN customer_code VARCHAR(32) NULL AFTER id,
    ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' AFTER type,
    ADD COLUMN display_name VARCHAR(180) NULL AFTER name_km,
    ADD COLUMN email VARCHAR(150) NULL AFTER phone,
    ADD COLUMN address VARCHAR(255) NULL AFTER email,
    ADD COLUMN contact_person VARCHAR(150) NULL AFTER address,
    ADD COLUMN payment_terms VARCHAR(80) NULL AFTER contact_person,
    ADD COLUMN tax_number VARCHAR(80) NULL AFTER payment_terms,
    ADD COLUMN notes TEXT NULL AFTER tax_number;

UPDATE customers
SET customer_code = CONCAT('CUST', LPAD(id, 5, '0'))
WHERE customer_code IS NULL;

UPDATE customers
SET display_name = COALESCE(NULLIF(TRIM(name_en), ''), NULLIF(TRIM(name_km), ''), CONCAT('Customer #', id))
WHERE display_name IS NULL;

ALTER TABLE customers
    MODIFY COLUMN customer_code VARCHAR(32) NOT NULL,
    ADD CONSTRAINT uk_customers_customer_code UNIQUE (customer_code);
