-- Add timestamps to sales table for BaseEntity compatibility
SET @sales_updated_at_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'sales'
    AND COLUMN_NAME = 'updated_at'
);

SET @sales_updated_at_sql := IF(
  @sales_updated_at_exists = 0,
  'ALTER TABLE sales ADD COLUMN updated_at TIMESTAMP NULL DEFAULT NULL',
  'SELECT 1'
);

PREPARE stmt FROM @sales_updated_at_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Backfill updated_at where missing
UPDATE sales SET updated_at = COALESCE(updated_at, created_at);
