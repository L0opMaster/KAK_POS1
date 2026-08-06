-- Allow inserts without sale_number since Sale entity does not map it
ALTER TABLE sales
  MODIFY sale_number VARCHAR(50) NULL;

-- Backfill sale_number from client_ref where missing
SET @sales_client_ref_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'sales'
    AND COLUMN_NAME = 'client_ref'
);

SET @sales_client_ref_sql := IF(
  @sales_client_ref_exists > 0,
  'UPDATE sales SET sale_number = client_ref WHERE sale_number IS NULL AND client_ref IS NOT NULL',
  'SELECT 1'
);

PREPARE stmt FROM @sales_client_ref_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
