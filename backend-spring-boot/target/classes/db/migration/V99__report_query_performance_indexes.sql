-- V99: Performance indexes for report date-range queries.

SET @idx_payments_status_created_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'payments'
    AND INDEX_NAME = 'idx_payments_status_created_id'
);
SET @idx_payments_status_created_id_sql := IF(
  @idx_payments_status_created_id_exists = 0,
  'CREATE INDEX idx_payments_status_created_id ON payments (status, created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_payments_status_created_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_sales_status_created_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'sales'
    AND INDEX_NAME = 'idx_sales_status_created_id'
);
SET @idx_sales_status_created_id_sql := IF(
  @idx_sales_status_created_id_exists = 0,
  'CREATE INDEX idx_sales_status_created_id ON sales (status, created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_sales_status_created_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_goods_receipts_received_created_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'goods_receipts'
    AND INDEX_NAME = 'idx_goods_receipts_received_created'
);
SET @idx_goods_receipts_received_created_sql := IF(
  @idx_goods_receipts_received_created_exists = 0,
  'CREATE INDEX idx_goods_receipts_received_created ON goods_receipts (received_at, created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_goods_receipts_received_created_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
