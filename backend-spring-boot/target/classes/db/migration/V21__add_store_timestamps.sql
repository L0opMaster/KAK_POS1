-- Add timestamps to stores table for BaseEntity compatibility
SET @stores_updated_at_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'stores'
    AND COLUMN_NAME = 'updated_at'
);

SET @stores_updated_at_sql := IF(
  @stores_updated_at_exists = 0,
  'ALTER TABLE stores ADD COLUMN updated_at TIMESTAMP NULL DEFAULT NULL',
  'SELECT 1'
);

PREPARE stmt FROM @stores_updated_at_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Backfill updated_at where missing
UPDATE stores SET updated_at = COALESCE(updated_at, created_at);
