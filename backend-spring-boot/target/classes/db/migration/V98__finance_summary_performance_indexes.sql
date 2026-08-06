-- V98: Performance indexes for finance AP/AR summaries and AP ledger.

SET @idx_sales_status_credit_due_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'sales'
    AND INDEX_NAME = 'idx_sales_status_credit_due'
);
SET @idx_sales_status_credit_due_sql := IF(
  @idx_sales_status_credit_due_exists = 0,
  'CREATE INDEX idx_sales_status_credit_due ON sales (status, credit_due_at, created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_sales_status_credit_due_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_supplier_invoices_due_invoice_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_invoices'
    AND INDEX_NAME = 'idx_supplier_invoices_due_invoice_id'
);
SET @idx_supplier_invoices_due_invoice_id_sql := IF(
  @idx_supplier_invoices_due_invoice_id_exists = 0,
  'CREATE INDEX idx_supplier_invoices_due_invoice_id ON supplier_invoices (due_date, invoice_date, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_supplier_invoices_due_invoice_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_supplier_invoices_created_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_invoices'
    AND INDEX_NAME = 'idx_supplier_invoices_created_id'
);
SET @idx_supplier_invoices_created_id_sql := IF(
  @idx_supplier_invoices_created_id_exists = 0,
  'CREATE INDEX idx_supplier_invoices_created_id ON supplier_invoices (created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_supplier_invoices_created_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_purchase_returns_created_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'purchase_returns'
    AND INDEX_NAME = 'idx_purchase_returns_created_id'
);
SET @idx_purchase_returns_created_id_sql := IF(
  @idx_purchase_returns_created_id_exists = 0,
  'CREATE INDEX idx_purchase_returns_created_id ON purchase_returns (created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_purchase_returns_created_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_purchase_rfqs_status_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'purchase_rfqs'
    AND INDEX_NAME = 'idx_purchase_rfqs_status'
);
SET @idx_purchase_rfqs_status_sql := IF(
  @idx_purchase_rfqs_status_exists = 0,
  'CREATE INDEX idx_purchase_rfqs_status ON purchase_rfqs (status)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_purchase_rfqs_status_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_purchase_orders_status_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'purchase_orders'
    AND INDEX_NAME = 'idx_purchase_orders_status'
);
SET @idx_purchase_orders_status_sql := IF(
  @idx_purchase_orders_status_exists = 0,
  'CREATE INDEX idx_purchase_orders_status ON purchase_orders (status)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_purchase_orders_status_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_stock_items_low_stock_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'stock_items'
    AND INDEX_NAME = 'idx_stock_items_low_stock'
);
SET @idx_stock_items_low_stock_sql := IF(
  @idx_stock_items_low_stock_exists = 0,
  'CREATE INDEX idx_stock_items_low_stock ON stock_items (low_stock_threshold, quantity, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_stock_items_low_stock_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
