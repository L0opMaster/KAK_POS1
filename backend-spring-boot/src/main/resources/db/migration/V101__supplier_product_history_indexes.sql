-- V101: Performance indexes for supplier summaries and product history lookups.

SET @idx_supplier_catalog_items_supplier_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_catalog_items'
    AND INDEX_NAME = 'idx_supplier_catalog_items_supplier'
);
SET @idx_supplier_catalog_items_supplier_sql := IF(
  @idx_supplier_catalog_items_supplier_exists = 0,
  'CREATE INDEX idx_supplier_catalog_items_supplier ON supplier_catalog_items (supplier_id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_supplier_catalog_items_supplier_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_purchase_lines_product_purchase_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'purchase_lines'
    AND INDEX_NAME = 'idx_purchase_lines_product_purchase'
);
SET @idx_purchase_lines_product_purchase_sql := IF(
  @idx_purchase_lines_product_purchase_exists = 0,
  'CREATE INDEX idx_purchase_lines_product_purchase ON purchase_lines (product_id, purchase_id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_purchase_lines_product_purchase_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_goods_receipt_lines_product_receipt_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'goods_receipt_lines'
    AND INDEX_NAME = 'idx_goods_receipt_lines_product_receipt'
);
SET @idx_goods_receipt_lines_product_receipt_sql := IF(
  @idx_goods_receipt_lines_product_receipt_exists = 0,
  'CREATE INDEX idx_goods_receipt_lines_product_receipt ON goods_receipt_lines (product_id, goods_receipt_id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_goods_receipt_lines_product_receipt_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_supplier_invoice_lines_product_invoice_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_invoice_lines'
    AND INDEX_NAME = 'idx_supplier_invoice_lines_product_invoice'
);
SET @idx_supplier_invoice_lines_product_invoice_sql := IF(
  @idx_supplier_invoice_lines_product_invoice_exists = 0,
  'CREATE INDEX idx_supplier_invoice_lines_product_invoice ON supplier_invoice_lines (product_id, supplier_invoice_id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_supplier_invoice_lines_product_invoice_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_stock_transfer_lines_product_transfer_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'stock_transfer_lines'
    AND INDEX_NAME = 'idx_stock_transfer_lines_product_transfer'
);
SET @idx_stock_transfer_lines_product_transfer_sql := IF(
  @idx_stock_transfer_lines_product_transfer_exists = 0,
  'CREATE INDEX idx_stock_transfer_lines_product_transfer ON stock_transfer_lines (product_id, transfer_id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_stock_transfer_lines_product_transfer_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_inventory_snapshots_product_posted_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'inventory_snapshots'
    AND INDEX_NAME = 'idx_inventory_snapshots_product_posted'
);
SET @idx_inventory_snapshots_product_posted_sql := IF(
  @idx_inventory_snapshots_product_posted_exists = 0,
  'CREATE INDEX idx_inventory_snapshots_product_posted ON inventory_snapshots (product_id, posted_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_inventory_snapshots_product_posted_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_production_recipes_output_name_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'production_recipes'
    AND INDEX_NAME = 'idx_production_recipes_output_name'
);
SET @idx_production_recipes_output_name_sql := IF(
  @idx_production_recipes_output_name_exists = 0,
  'CREATE INDEX idx_production_recipes_output_name ON production_recipes (output_product_id, name)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_production_recipes_output_name_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
