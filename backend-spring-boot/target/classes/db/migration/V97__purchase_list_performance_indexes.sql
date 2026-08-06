-- V97: Performance indexes for high-growth purchase list screens.
--
-- These indexes match the server-side filters and sort order used by purchase orders,
-- supplier bills, and supplier payment history.

SET @idx_purchase_orders_supplier_status_ordered_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'purchase_orders'
    AND INDEX_NAME = 'idx_purchase_orders_supplier_status_ordered'
);
SET @idx_purchase_orders_supplier_status_ordered_sql := IF(
  @idx_purchase_orders_supplier_status_ordered_exists = 0,
  'CREATE INDEX idx_purchase_orders_supplier_status_ordered ON purchase_orders (supplier_id, status, ordered_at)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_purchase_orders_supplier_status_ordered_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_purchase_orders_ordered_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'purchase_orders'
    AND INDEX_NAME = 'idx_purchase_orders_ordered_id'
);
SET @idx_purchase_orders_ordered_id_sql := IF(
  @idx_purchase_orders_ordered_id_exists = 0,
  'CREATE INDEX idx_purchase_orders_ordered_id ON purchase_orders (ordered_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_purchase_orders_ordered_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_supplier_invoices_supplier_status_date_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_invoices'
    AND INDEX_NAME = 'idx_supplier_invoices_supplier_status_date'
);
SET @idx_supplier_invoices_supplier_status_date_sql := IF(
  @idx_supplier_invoices_supplier_status_date_exists = 0,
  'CREATE INDEX idx_supplier_invoices_supplier_status_date ON supplier_invoices (supplier_id, status, invoice_date)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_supplier_invoices_supplier_status_date_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_supplier_invoices_date_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_invoices'
    AND INDEX_NAME = 'idx_supplier_invoices_date_id'
);
SET @idx_supplier_invoices_date_id_sql := IF(
  @idx_supplier_invoices_date_id_exists = 0,
  'CREATE INDEX idx_supplier_invoices_date_id ON supplier_invoices (invoice_date, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_supplier_invoices_date_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_supplier_invoices_due_status_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_invoices'
    AND INDEX_NAME = 'idx_supplier_invoices_due_status'
);
SET @idx_supplier_invoices_due_status_sql := IF(
  @idx_supplier_invoices_due_status_exists = 0,
  'CREATE INDEX idx_supplier_invoices_due_status ON supplier_invoices (due_date, status)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_supplier_invoices_due_status_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_supplier_payments_paid_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_payments'
    AND INDEX_NAME = 'idx_supplier_payments_paid_id'
);
SET @idx_supplier_payments_paid_id_sql := IF(
  @idx_supplier_payments_paid_id_exists = 0,
  'CREATE INDEX idx_supplier_payments_paid_id ON supplier_payments (paid_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_supplier_payments_paid_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_supplier_payments_invoice_paid_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'supplier_payments'
    AND INDEX_NAME = 'idx_supplier_payments_invoice_paid'
);
SET @idx_supplier_payments_invoice_paid_sql := IF(
  @idx_supplier_payments_invoice_paid_exists = 0,
  'CREATE INDEX idx_supplier_payments_invoice_paid ON supplier_payments (supplier_invoice_id, paid_at)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_supplier_payments_invoice_paid_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
