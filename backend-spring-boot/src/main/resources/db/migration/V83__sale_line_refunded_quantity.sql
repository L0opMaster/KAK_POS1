-- V83: Persist refunded sale line quantity so stock returns stay bounded across repeated refunds

SET @sale_lines_refunded_quantity_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'sale_lines'
    AND COLUMN_NAME = 'refunded_quantity'
);
SET @sale_lines_refunded_quantity_sql := IF(
  @sale_lines_refunded_quantity_exists = 0,
  'ALTER TABLE sale_lines ADD COLUMN refunded_quantity DECIMAL(18,2) NOT NULL DEFAULT 0.00',
  'SELECT 1'
);
PREPARE stmt FROM @sale_lines_refunded_quantity_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
