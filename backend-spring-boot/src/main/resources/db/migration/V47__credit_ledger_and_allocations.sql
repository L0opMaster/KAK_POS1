-- V47: Credit ledger foundation (terms, opening balances, allocations)

-- 1) Extend sales with credit term metadata
SET @credit_issued_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'credit_issued_at'
);

SET @sql := IF(
    @credit_issued_exists = 0,
    'ALTER TABLE sales ADD COLUMN credit_issued_at TIMESTAMP NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @credit_due_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'credit_due_at'
);

SET @sql := IF(
    @credit_due_exists = 0,
    'ALTER TABLE sales ADD COLUMN credit_due_at TIMESTAMP NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @credit_term_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'credit_term_days'
);

SET @sql := IF(
    @credit_term_exists = 0,
    'ALTER TABLE sales ADD COLUMN credit_term_days INT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) Create customer opening balance table
CREATE TABLE IF NOT EXISTS customer_credit_opening_balances (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    original_amount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    remaining_amount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    note VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_v47_ccob_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
);

SET @idx_ccob_customer_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'customer_credit_opening_balances'
      AND INDEX_NAME = 'idx_ccob_customer'
);
SET @sql := IF(
    @idx_ccob_customer_exists = 0,
    'CREATE INDEX idx_ccob_customer ON customer_credit_opening_balances(customer_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_ccob_customer_remaining_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'customer_credit_opening_balances'
      AND INDEX_NAME = 'idx_ccob_customer_remaining'
);
SET @sql := IF(
    @idx_ccob_customer_remaining_exists = 0,
    'CREATE INDEX idx_ccob_customer_remaining ON customer_credit_opening_balances(customer_id, remaining_amount)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3) Create allocation table for customer credit collections
CREATE TABLE IF NOT EXISTS customer_credit_allocations (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    payment_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    target_type VARCHAR(32) NOT NULL,
    sale_id BIGINT NULL,
    opening_balance_id BIGINT NULL,
    amount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    note VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_v47_cca_payment FOREIGN KEY (payment_id) REFERENCES payments(id),
    CONSTRAINT fk_v47_cca_customer FOREIGN KEY (customer_id) REFERENCES customers(id),
    CONSTRAINT fk_v47_cca_sale FOREIGN KEY (sale_id) REFERENCES sales(id),
    CONSTRAINT fk_v47_cca_opening FOREIGN KEY (opening_balance_id) REFERENCES customer_credit_opening_balances(id)
);

SET @idx_cca_customer_created_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'customer_credit_allocations'
      AND INDEX_NAME = 'idx_cca_customer_created'
);
SET @sql := IF(
    @idx_cca_customer_created_exists = 0,
    'CREATE INDEX idx_cca_customer_created ON customer_credit_allocations(customer_id, created_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_cca_payment_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'customer_credit_allocations'
      AND INDEX_NAME = 'idx_cca_payment'
);
SET @sql := IF(
    @idx_cca_payment_exists = 0,
    'CREATE INDEX idx_cca_payment ON customer_credit_allocations(payment_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_cca_sale_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'customer_credit_allocations'
      AND INDEX_NAME = 'idx_cca_sale'
);
SET @sql := IF(
    @idx_cca_sale_exists = 0,
    'CREATE INDEX idx_cca_sale ON customer_credit_allocations(sale_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_cca_opening_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'customer_credit_allocations'
      AND INDEX_NAME = 'idx_cca_opening'
);
SET @sql := IF(
    @idx_cca_opening_exists = 0,
    'CREATE INDEX idx_cca_opening ON customer_credit_allocations(opening_balance_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 4) Add index for FIFO credit lookup
SET @idx_sales_customer_credit_fifo_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND INDEX_NAME = 'idx_sales_customer_credit_fifo'
);
SET @sql := IF(
    @idx_sales_customer_credit_fifo_exists = 0,
    'CREATE INDEX idx_sales_customer_credit_fifo ON sales(customer_id, status, credit_due_at, created_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 5) Backfill credit metadata for existing credit sales
UPDATE sales
SET credit_issued_at = COALESCE(credit_issued_at, created_at),
    credit_due_at = COALESCE(credit_due_at, DATE_ADD(created_at, INTERVAL 30 DAY)),
    credit_term_days = COALESCE(credit_term_days, 30)
WHERE status = 'CREDIT';

-- 6) Legacy migration: preserve existing customer credit balances
INSERT INTO customer_credit_opening_balances (
    customer_id,
    original_amount,
    remaining_amount,
    note
)
SELECT c.id,
       c.credit_balance,
       c.credit_balance,
       'Legacy opening balance migration (V47)'
FROM customers c
WHERE c.credit_balance > 0
  AND NOT EXISTS (
      SELECT 1
      FROM customer_credit_opening_balances ob
      WHERE ob.customer_id = c.id
  );
