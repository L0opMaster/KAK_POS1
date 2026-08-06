-- V84: Track delivered and stock-deducted quantity per sale line

SET @sale_lines_delivered_quantity_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'sale_lines'
    AND COLUMN_NAME = 'delivered_quantity'
);
SET @sale_lines_delivered_quantity_sql := IF(
  @sale_lines_delivered_quantity_exists = 0,
  'ALTER TABLE sale_lines ADD COLUMN delivered_quantity DECIMAL(18,2) NOT NULL DEFAULT 0.00',
  'SELECT 1'
);
PREPARE stmt FROM @sale_lines_delivered_quantity_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sale_lines_stock_deducted_quantity_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'sale_lines'
    AND COLUMN_NAME = 'stock_deducted_quantity'
);
SET @sale_lines_stock_deducted_quantity_sql := IF(
  @sale_lines_stock_deducted_quantity_exists = 0,
  'ALTER TABLE sale_lines ADD COLUMN stock_deducted_quantity DECIMAL(18,2) NOT NULL DEFAULT 0.00',
  'SELECT 1'
);
PREPARE stmt FROM @sale_lines_stock_deducted_quantity_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
