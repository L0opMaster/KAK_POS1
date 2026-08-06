-- V82: Performance indexes for inventory & stock movement queries
--
-- 1. stock_movements: composite index on (store_id, created_at DESC) — used by the per-store
--    movements query that was previously doing a full table scan.
-- 2. stock_movements: composite index on (product_id, created_at DESC) — used by the per-product
--    movements history query.
-- 3. inventory_snapshots: composite index on (snapshot_date, store_id) — used by count entry
--    and post-count queries.
-- 4. Extend movement_type column to 30 chars to accommodate new types like PRODUCTION_CANCEL
--    without silent truncation.

SET @idx_stock_movements_store_created_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'stock_movements'
    AND INDEX_NAME = 'idx_stock_movements_store_created'
);
SET @idx_stock_movements_store_created_sql := IF(
  @idx_stock_movements_store_created_exists = 0,
  'CREATE INDEX idx_stock_movements_store_created ON stock_movements (store_id, created_at DESC)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_stock_movements_store_created_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_stock_movements_product_created_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'stock_movements'
    AND INDEX_NAME = 'idx_stock_movements_product_created'
);
SET @idx_stock_movements_product_created_sql := IF(
  @idx_stock_movements_product_created_exists = 0,
  'CREATE INDEX idx_stock_movements_product_created ON stock_movements (product_id, created_at DESC)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_stock_movements_product_created_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_inventory_snapshots_date_store_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'inventory_snapshots'
    AND INDEX_NAME = 'idx_inventory_snapshots_date_store'
);
SET @idx_inventory_snapshots_date_store_sql := IF(
  @idx_inventory_snapshots_date_store_exists = 0,
  'CREATE INDEX idx_inventory_snapshots_date_store ON inventory_snapshots (snapshot_date, store_id)',
  'SELECT 1'
);
PREPARE stmt FROM @idx_inventory_snapshots_date_store_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

ALTER TABLE stock_movements
    MODIFY COLUMN movement_type VARCHAR(30) NOT NULL;
