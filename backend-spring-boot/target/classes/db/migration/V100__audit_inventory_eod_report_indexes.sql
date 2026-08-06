-- V100: Performance indexes for audit, inventory, shift, and EOD report paths.

SET @idx_audit_logs_created_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'audit_logs'
    AND INDEX_NAME = 'idx_audit_logs_created_id'
);
SET @idx_audit_logs_created_id_sql := IF(
  @idx_audit_logs_created_id_exists = 0,
  'CREATE INDEX idx_audit_logs_created_id ON audit_logs (created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_audit_logs_created_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_login_audit_logs_created_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'login_audit_logs'
    AND INDEX_NAME = 'idx_login_audit_logs_created_id'
);
SET @idx_login_audit_logs_created_id_sql := IF(
  @idx_login_audit_logs_created_id_exists = 0,
  'CREATE INDEX idx_login_audit_logs_created_id ON login_audit_logs (created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_login_audit_logs_created_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_shifts_opened_id_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'shifts'
    AND INDEX_NAME = 'idx_shifts_opened_id'
);
SET @idx_shifts_opened_id_sql := IF(
  @idx_shifts_opened_id_exists = 0,
  'CREATE INDEX idx_shifts_opened_id ON shifts (opened_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_shifts_opened_id_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_shifts_closed_variance_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'shifts'
    AND INDEX_NAME = 'idx_shifts_closed_variance'
);
SET @idx_shifts_closed_variance_sql := IF(
  @idx_shifts_closed_variance_exists = 0,
  'CREATE INDEX idx_shifts_closed_variance ON shifts (closed_at, variance)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_shifts_closed_variance_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_inventory_snapshots_date_created_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'inventory_snapshots'
    AND INDEX_NAME = 'idx_inventory_snapshots_date_created'
);
SET @idx_inventory_snapshots_date_created_sql := IF(
  @idx_inventory_snapshots_date_created_exists = 0,
  'CREATE INDEX idx_inventory_snapshots_date_created ON inventory_snapshots (snapshot_date, created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_inventory_snapshots_date_created_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_sales_status_order_created_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'sales'
    AND INDEX_NAME = 'idx_sales_status_order_created'
);
SET @idx_sales_status_order_created_sql := IF(
  @idx_sales_status_order_created_exists = 0,
  'CREATE INDEX idx_sales_status_order_created ON sales (status, order_date, created_at, id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_sales_status_order_created_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
