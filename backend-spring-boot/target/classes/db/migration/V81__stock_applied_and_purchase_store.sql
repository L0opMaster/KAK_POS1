-- V81: Fix stock management correctness
--
-- 1. sales.stock_applied  – guards against double stock deduction on split payments and pay+credit races
-- 2. purchases.store_id   – records which store a purchase is destined for (fixes hard-coded store 1 bug)

SET @sales_stock_applied_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'sales'
    AND COLUMN_NAME = 'stock_applied'
);
SET @sales_stock_applied_sql := IF(
  @sales_stock_applied_exists = 0,
  'ALTER TABLE sales ADD COLUMN stock_applied BOOLEAN NOT NULL DEFAULT FALSE',
  'SELECT 1'
);
PREPARE stmt FROM @sales_stock_applied_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Back-fill: any sale already in PAID/CREDIT/REFUNDED/PARTIALLY_REFUNDED state has already had
-- stock deducted, so mark it applied so the guard never re-runs on old records.
UPDATE sales
SET stock_applied = TRUE
WHERE status IN ('PAID', 'CREDIT', 'REFUNDED', 'PARTIALLY_REFUNDED');

SET @purchases_store_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'purchases'
    AND COLUMN_NAME = 'store_id'
);
SET @purchases_store_sql := IF(
  @purchases_store_exists = 0,
  'ALTER TABLE purchases ADD COLUMN store_id BIGINT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @purchases_store_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @purchases_store_fk_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'purchases'
    AND CONSTRAINT_NAME = 'fk_purchases_store'
);
SET @purchases_store_fk_sql := IF(
  @purchases_store_fk_exists = 0,
  'ALTER TABLE purchases ADD CONSTRAINT fk_purchases_store FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE SET NULL',
  'SELECT 1'
);
PREPARE stmt FROM @purchases_store_fk_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
