-- V44: Align legacy shifts schema with current Shift entity fields (idempotent)

-- Add opened_by if missing.
SET @opened_by_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND COLUMN_NAME = 'opened_by'
);
SET @sql := IF(
    @opened_by_exists = 0,
    'ALTER TABLE shifts ADD COLUMN opened_by BIGINT NULL AFTER id',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add closed_by if missing.
SET @closed_by_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND COLUMN_NAME = 'closed_by'
);
SET @sql := IF(
    @closed_by_exists = 0,
    'ALTER TABLE shifts ADD COLUMN closed_by BIGINT NULL AFTER closed_at',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add variance if missing.
SET @variance_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND COLUMN_NAME = 'variance'
);
SET @sql := IF(
    @variance_exists = 0,
    'ALTER TABLE shifts ADD COLUMN variance DECIMAL(18,2) NULL AFTER expected_cash',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Relax legacy cashier_id NOT NULL so current entity inserts using opened_by can succeed.
SET @cashier_col_is_nullable := (
    SELECT IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND COLUMN_NAME = 'cashier_id'
    LIMIT 1
);
SET @sql := IF(
    @cashier_col_is_nullable = 'NO',
    'ALTER TABLE shifts MODIFY COLUMN cashier_id BIGINT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backfill opened_by from cashier_id when possible.
SET @cashier_id_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND COLUMN_NAME = 'cashier_id'
);
SET @sql := IF(
    @cashier_id_exists = 1,
    'UPDATE shifts SET opened_by = cashier_id WHERE opened_by IS NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Keep legacy cashier_id populated from opened_by for backward compatibility.
SET @sql := IF(
    @cashier_id_exists = 1,
    'UPDATE shifts SET cashier_id = opened_by WHERE cashier_id IS NULL AND opened_by IS NOT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backfill variance from cash_variance when possible.
SET @cash_variance_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND COLUMN_NAME = 'cash_variance'
);
SET @sql := IF(
    @cash_variance_exists = 1,
    'UPDATE shifts SET variance = cash_variance WHERE variance IS NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure opened_by FK exists.
SET @fk_opened_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND CONSTRAINT_NAME = 'fk_shift_opened_by'
);
SET @sql := IF(
    @fk_opened_exists = 0,
    'ALTER TABLE shifts ADD CONSTRAINT fk_shift_opened_by FOREIGN KEY (opened_by) REFERENCES users(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure closed_by FK exists.
SET @fk_closed_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND CONSTRAINT_NAME = 'fk_shift_closed_by'
);
SET @sql := IF(
    @fk_closed_exists = 0,
    'ALTER TABLE shifts ADD CONSTRAINT fk_shift_closed_by FOREIGN KEY (closed_by) REFERENCES users(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure opened_by index exists for current queries.
SET @idx_opened_by_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND INDEX_NAME = 'idx_opened_by'
);
SET @sql := IF(
    @idx_opened_by_exists = 0,
    'CREATE INDEX idx_opened_by ON shifts(opened_by)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
