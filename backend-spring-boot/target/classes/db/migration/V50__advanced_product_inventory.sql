CREATE TABLE IF NOT EXISTS units (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    base_unit_group VARCHAR(60) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO units (code, name, symbol, base_unit_group, active) VALUES
('EACH', 'Each', 'ea', 'COUNT', TRUE),
('BOX', 'Box', 'box', 'COUNT', TRUE),
('CASE', 'Case', 'case', 'COUNT', TRUE),
('PACK', 'Pack', 'pack', 'COUNT', TRUE),
('BOTTLE', 'Bottle', 'btl', 'COUNT', TRUE),
('KG', 'Kilogram', 'kg', 'WEIGHT', TRUE),
('G', 'Gram', 'g', 'WEIGHT', TRUE),
('L', 'Liter', 'l', 'VOLUME', TRUE),
('ML', 'Milliliter', 'ml', 'VOLUME', TRUE)
AS incoming_unit
ON DUPLICATE KEY UPDATE
    name = incoming_unit.name,
    symbol = incoming_unit.symbol,
    base_unit_group = incoming_unit.base_unit_group,
    active = incoming_unit.active;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND COLUMN_NAME = 'sellable'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN sellable BOOLEAN NOT NULL DEFAULT TRUE',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND COLUMN_NAME = 'purchasable'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN purchasable BOOLEAN NOT NULL DEFAULT FALSE',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND COLUMN_NAME = 'product_type'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN product_type VARCHAR(40) NOT NULL DEFAULT ''SALE_ITEM''',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND COLUMN_NAME = 'low_stock_threshold'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN low_stock_threshold DECIMAL(18,2) NOT NULL DEFAULT 5.00',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND COLUMN_NAME = 'sale_unit_id'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN sale_unit_id BIGINT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND COLUMN_NAME = 'purchase_unit_id'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN purchase_unit_id BIGINT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND COLUMN_NAME = 'stock_unit_id'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN stock_unit_id BIGINT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE products
SET sellable = active,
    purchasable = CASE WHEN track_inventory = TRUE THEN TRUE ELSE FALSE END,
    product_type = CASE WHEN track_inventory = TRUE THEN 'STOCK_ITEM' ELSE 'SALE_ITEM' END
WHERE sellable IS NULL
   OR purchasable IS NULL
   OR product_type IS NULL;

UPDATE products p
JOIN units u ON u.code = 'EACH'
SET p.sale_unit_id = COALESCE(p.sale_unit_id, u.id),
    p.purchase_unit_id = COALESCE(p.purchase_unit_id, u.id),
    p.stock_unit_id = COALESCE(p.stock_unit_id, u.id)
WHERE p.sale_unit_id IS NULL
   OR p.purchase_unit_id IS NULL
   OR p.stock_unit_id IS NULL;

SET @fk_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND CONSTRAINT_NAME = 'fk_products_sale_unit'
);
SET @sql := IF(
    @fk_exists = 0,
    'ALTER TABLE products ADD CONSTRAINT fk_products_sale_unit FOREIGN KEY (sale_unit_id) REFERENCES units(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @fk_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND CONSTRAINT_NAME = 'fk_products_purchase_unit'
);
SET @sql := IF(
    @fk_exists = 0,
    'ALTER TABLE products ADD CONSTRAINT fk_products_purchase_unit FOREIGN KEY (purchase_unit_id) REFERENCES units(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @fk_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND CONSTRAINT_NAME = 'fk_products_stock_unit'
);
SET @sql := IF(
    @fk_exists = 0,
    'ALTER TABLE products ADD CONSTRAINT fk_products_stock_unit FOREIGN KEY (stock_unit_id) REFERENCES units(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS product_unit_conversions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_product_id BIGINT NOT NULL,
    target_product_id BIGINT NOT NULL,
    source_unit_id BIGINT NOT NULL,
    target_unit_id BIGINT NOT NULL,
    ratio DECIMAL(18,4) NOT NULL,
    conversion_type VARCHAR(40) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_product_conv_source_product FOREIGN KEY (source_product_id) REFERENCES products(id),
    CONSTRAINT fk_product_conv_target_product FOREIGN KEY (target_product_id) REFERENCES products(id),
    CONSTRAINT fk_product_conv_source_unit FOREIGN KEY (source_unit_id) REFERENCES units(id),
    CONSTRAINT fk_product_conv_target_unit FOREIGN KEY (target_unit_id) REFERENCES units(id)
);

CREATE TABLE IF NOT EXISTS inventory_snapshots (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    snapshot_date DATE NOT NULL,
    product_id BIGINT NOT NULL,
    store_id BIGINT NOT NULL,
    quantity DECIMAL(18,2) NOT NULL,
    counted_quantity DECIMAL(18,2) NULL,
    variance_quantity DECIMAL(18,2) NULL,
    count_status VARCHAR(20) NOT NULL DEFAULT 'SNAPSHOT',
    posted_at TIMESTAMP NULL,
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_inventory_snapshot_product FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT fk_inventory_snapshot_store FOREIGN KEY (store_id) REFERENCES stores(id)
);

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'inventory_snapshots'
      AND COLUMN_NAME = 'counted_quantity'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE inventory_snapshots ADD COLUMN counted_quantity DECIMAL(18,2) NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'inventory_snapshots'
      AND COLUMN_NAME = 'variance_quantity'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE inventory_snapshots ADD COLUMN variance_quantity DECIMAL(18,2) NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'inventory_snapshots'
      AND COLUMN_NAME = 'count_status'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE inventory_snapshots ADD COLUMN count_status VARCHAR(20) NOT NULL DEFAULT ''SNAPSHOT''',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'inventory_snapshots'
      AND COLUMN_NAME = 'posted_at'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE inventory_snapshots ADD COLUMN posted_at TIMESTAMP NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'inventory_snapshots'
      AND COLUMN_NAME = 'notes'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE inventory_snapshots ADD COLUMN notes VARCHAR(255) NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
