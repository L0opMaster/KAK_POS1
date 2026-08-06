-- V45: Align legacy sales schema with current Sale entity fields (idempotent)

-- Add tax_rate if missing.
SET @tax_rate_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'tax_rate'
);
SET @sql := IF(
    @tax_rate_exists = 0,
    'ALTER TABLE sales ADD COLUMN tax_rate DOUBLE NOT NULL DEFAULT 0.10 AFTER discount_amount',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add tax_amount if missing.
SET @tax_amount_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'tax_amount'
);
SET @sql := IF(
    @tax_amount_exists = 0,
    'ALTER TABLE sales ADD COLUMN tax_amount DECIMAL(18,2) NOT NULL DEFAULT 0.00 AFTER tax_rate',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add grand_total if missing.
SET @grand_total_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'grand_total'
);
SET @sql := IF(
    @grand_total_exists = 0,
    'ALTER TABLE sales ADD COLUMN grand_total DECIMAL(18,2) NOT NULL DEFAULT 0.00 AFTER tax_amount',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add note if missing.
SET @note_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'note'
);
SET @sql := IF(
    @note_exists = 0,
    'ALTER TABLE sales ADD COLUMN note VARCHAR(255) NULL AFTER change_amount',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add client_ref if missing.
SET @client_ref_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'client_ref'
);
SET @sql := IF(
    @client_ref_exists = 0,
    'ALTER TABLE sales ADD COLUMN client_ref VARCHAR(64) NULL AFTER note',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backfill grand_total from total_amount.
SET @sql := IF(
    @grand_total_exists = 0,
    'UPDATE sales SET grand_total = total_amount WHERE grand_total = 0 AND total_amount IS NOT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backfill note from legacy notes column when available.
SET @notes_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'notes'
);
SET @sql := IF(
    @notes_exists = 1,
    'UPDATE sales SET note = notes WHERE note IS NULL AND notes IS NOT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure index for client_ref exists.
SET @idx_client_ref_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND INDEX_NAME = 'idx_sales_client_ref'
);
SET @sql := IF(
    @idx_client_ref_exists = 0,
    'CREATE INDEX idx_sales_client_ref ON sales(client_ref)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
