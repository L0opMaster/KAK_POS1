-- V28: Align stock_items + stock_movements schema

-- Ensure a default store exists
SET @store_exists := (SELECT COUNT(*) FROM stores);
SET @store_sql := IF(@store_exists = 0,
  "INSERT INTO stores (name, address, phone, created_at, updated_at) VALUES ('Main Store', 'Phnom Penh, Cambodia', '+855 23 123 456', NOW(), NOW())",
  'SELECT 1'
);
PREPARE stmt FROM @store_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Create stock_items table if missing
CREATE TABLE IF NOT EXISTS stock_items (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  product_id BIGINT NOT NULL,
  store_id BIGINT NOT NULL,
  quantity DECIMAL(18,2) NOT NULL DEFAULT 0,
  low_stock_threshold DECIMAL(18,2) NOT NULL DEFAULT 0,
  version BIGINT DEFAULT 0,
  updated_at TIMESTAMP NULL,
  CONSTRAINT fk_stock_items_product FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT fk_stock_items_store FOREIGN KEY (store_id) REFERENCES stores(id),
  UNIQUE KEY uk_stock_items_store_product (store_id, product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- If legacy stocks table exists, backfill stock_items (once)
SET @stocks_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stocks'
);
SET @stock_items_count := (SELECT COUNT(*) FROM stock_items);
SET @backfill_sql := IF(@stocks_exists > 0 AND @stock_items_count = 0,
  'INSERT INTO stock_items (product_id, store_id, quantity, low_stock_threshold, updated_at)\n   SELECT s.product_id, 1, s.quantity, 0, NOW() FROM stocks s',
  'SELECT 1'
);
PREPARE stmt FROM @backfill_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure stock_movements has store_id
SET @store_col_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'store_id'
);
SET @add_store_sql := IF(@store_col_exists = 0,
  'ALTER TABLE stock_movements ADD COLUMN store_id BIGINT NULL AFTER product_id',
  'SELECT 1'
);
PREPARE stmt FROM @add_store_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Populate store_id where missing
UPDATE stock_movements SET store_id = 1 WHERE store_id IS NULL;

-- Make store_id NOT NULL
SET @store_col_nullable := (
  SELECT IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'store_id'
);
SET @alter_store_sql := IF(@store_col_nullable = 'YES',
  'ALTER TABLE stock_movements MODIFY COLUMN store_id BIGINT NOT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @alter_store_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure movement_type exists (map legacy type)
SET @movement_type_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'movement_type'
);
SET @type_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'type'
);
SET @add_movement_type_sql := IF(@movement_type_exists = 0,
  'ALTER TABLE stock_movements ADD COLUMN movement_type VARCHAR(20) NULL AFTER store_id',
  'SELECT 1'
);
PREPARE stmt FROM @add_movement_type_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @copy_type_sql := IF(@movement_type_exists = 0 AND @type_exists > 0,
  'UPDATE stock_movements SET movement_type = type WHERE movement_type IS NULL',
  'SELECT 1'
);
PREPARE stmt FROM @copy_type_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure reason column exists
SET @reason_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'reason'
);
SET @add_reason_sql := IF(@reason_exists = 0,
  'ALTER TABLE stock_movements ADD COLUMN reason VARCHAR(255) NULL AFTER quantity',
  'SELECT 1'
);
PREPARE stmt FROM @add_reason_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure created_at exists
SET @created_at_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'created_at'
);
SET @add_created_at_sql := IF(@created_at_exists = 0,
  'ALTER TABLE stock_movements ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
  'SELECT 1'
);
PREPARE stmt FROM @add_created_at_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure quantity type is DECIMAL(18,2)
SET @qty_type := (
  SELECT DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'quantity'
);
SET @qty_alter_sql := IF(@qty_type IS NOT NULL AND @qty_type <> 'decimal',
  'ALTER TABLE stock_movements MODIFY COLUMN quantity DECIMAL(18,2) NOT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @qty_alter_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add FK to stores if missing
SET @fk_store_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'stock_movements'
    AND CONSTRAINT_NAME = 'fk_stock_movements_store'
);
SET @add_fk_store_sql := IF(@fk_store_exists = 0,
  'ALTER TABLE stock_movements ADD CONSTRAINT fk_stock_movements_store FOREIGN KEY (store_id) REFERENCES stores(id)',
  'SELECT 1'
);
PREPARE stmt FROM @add_fk_store_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure movement_type NOT NULL where possible
UPDATE stock_movements SET movement_type = COALESCE(movement_type, 'ADJUST') WHERE movement_type IS NULL;
SET @movement_type_nullable := (
  SELECT IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'movement_type'
);
SET @movement_type_notnull_sql := IF(@movement_type_nullable = 'YES',
  'ALTER TABLE stock_movements MODIFY COLUMN movement_type VARCHAR(20) NOT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @movement_type_notnull_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
