-- V31: Remove legacy stock_movements.type column

-- Ensure movement_type exists before dropping legacy column
SET @movement_type_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'movement_type'
);
SET @add_movement_type_sql := IF(@movement_type_exists = 0,
  'ALTER TABLE stock_movements ADD COLUMN movement_type VARCHAR(20) NULL AFTER store_id',
  'SELECT 1'
);
PREPARE stmt FROM @add_movement_type_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Drop legacy type column if it exists (prevents NOT NULL errors on insert)
SET @type_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_movements' AND COLUMN_NAME = 'type'
);
SET @drop_type_sql := IF(@type_exists > 0,
  'ALTER TABLE stock_movements DROP COLUMN type',
  'SELECT 1'
);
PREPARE stmt FROM @drop_type_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
