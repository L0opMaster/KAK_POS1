-- V85: Track store and direct stock posting for supplier invoices

SET @supplier_invoices_store_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_invoices'
    AND COLUMN_NAME = 'store_id'
);
SET @supplier_invoices_store_id_sql := IF(
  @supplier_invoices_store_id_exists = 0,
  'ALTER TABLE supplier_invoices ADD COLUMN store_id BIGINT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @supplier_invoices_store_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @supplier_invoices_stock_applied_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_invoices'
    AND COLUMN_NAME = 'stock_applied'
);
SET @supplier_invoices_stock_applied_sql := IF(
  @supplier_invoices_stock_applied_exists = 0,
  'ALTER TABLE supplier_invoices ADD COLUMN stock_applied BIT(1) NOT NULL DEFAULT b''0''',
  'SELECT 1'
);
PREPARE stmt FROM @supplier_invoices_stock_applied_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @supplier_invoices_store_fk_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_invoices'
    AND COLUMN_NAME = 'store_id'
    AND REFERENCED_TABLE_NAME = 'stores'
);
SET @supplier_invoices_store_fk_sql := IF(
  @supplier_invoices_store_fk_exists = 0,
  'ALTER TABLE supplier_invoices ADD CONSTRAINT fk_supplier_invoices_store FOREIGN KEY (store_id) REFERENCES stores(id)',
  'SELECT 1'
);
PREPARE stmt FROM @supplier_invoices_store_fk_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
