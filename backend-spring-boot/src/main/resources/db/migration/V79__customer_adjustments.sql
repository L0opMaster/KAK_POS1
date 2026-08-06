-- V79: Customer credit/debit note adjustments

CREATE TABLE IF NOT EXISTS customer_adjustments (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_id      BIGINT        NOT NULL,
    type             VARCHAR(20)   NOT NULL,
    reference_number VARCHAR(60)   NOT NULL,
    amount           DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    reason           VARCHAR(255),
    note             VARCHAR(500),
    created_by       VARCHAR(150),
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP     NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_v79_ca_customer FOREIGN KEY (customer_id) REFERENCES customers(id),
    CONSTRAINT chk_v79_ca_amount CHECK (amount > 0)
);

SET @idx_ca_reference_exists = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'customer_adjustments'
      AND index_name = 'idx_ca_reference'
);
SET @idx_ca_reference_sql = IF(
    @idx_ca_reference_exists = 0,
    'CREATE UNIQUE INDEX idx_ca_reference ON customer_adjustments(reference_number)',
    'SELECT 1'
);
PREPARE stmt FROM @idx_ca_reference_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_ca_customer_created_exists = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'customer_adjustments'
      AND index_name = 'idx_ca_customer_created'
);
SET @idx_ca_customer_created_sql = IF(
    @idx_ca_customer_created_exists = 0,
    'CREATE INDEX idx_ca_customer_created ON customer_adjustments(customer_id, created_at)',
    'SELECT 1'
);
PREPARE stmt FROM @idx_ca_customer_created_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
