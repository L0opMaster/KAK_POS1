SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'products'
      AND COLUMN_NAME = 'parent_product_id'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN parent_product_id BIGINT NULL',
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
      AND COLUMN_NAME = 'variant_label'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN variant_label VARCHAR(120) NULL',
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
      AND COLUMN_NAME = 'bundle_mode'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE products ADD COLUMN bundle_mode VARCHAR(40) NULL',
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
      AND CONSTRAINT_NAME = 'fk_products_parent_product'
);
SET @sql := IF(
    @fk_exists = 0,
    'ALTER TABLE products ADD CONSTRAINT fk_products_parent_product FOREIGN KEY (parent_product_id) REFERENCES products(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS product_bundle_components (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    bundle_product_id BIGINT NOT NULL,
    component_product_id BIGINT NOT NULL,
    component_quantity DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_bundle_component_bundle_product FOREIGN KEY (bundle_product_id) REFERENCES products(id),
    CONSTRAINT fk_bundle_component_component_product FOREIGN KEY (component_product_id) REFERENCES products(id)
);

CREATE TABLE IF NOT EXISTS price_lists (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(150) NOT NULL,
    currency_code VARCHAR(12) NOT NULL,
    customer_group VARCHAR(80) NULL,
    store_id BIGINT NULL,
    starts_at TIMESTAMP NULL,
    ends_at TIMESTAMP NULL,
    priority INT NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_price_lists_store FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE IF NOT EXISTS price_list_items (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    price_list_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    price DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_price_list_items_price_list FOREIGN KEY (price_list_id) REFERENCES price_lists(id),
    CONSTRAINT fk_price_list_items_product FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT uk_price_list_items UNIQUE (price_list_id, product_id)
);

CREATE TABLE IF NOT EXISTS suppliers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(150) NOT NULL,
    phone VARCHAR(50) NULL,
    email VARCHAR(150) NULL,
    address VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL
);

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'suppliers'
      AND COLUMN_NAME = 'contact_person'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE suppliers ADD COLUMN contact_person VARCHAR(120) NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'suppliers'
      AND COLUMN_NAME = 'payment_terms'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE suppliers ADD COLUMN payment_terms VARCHAR(120) NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'suppliers'
      AND COLUMN_NAME = 'lead_time_days'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE suppliers ADD COLUMN lead_time_days INT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'suppliers'
      AND COLUMN_NAME = 'tax_id'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE suppliers ADD COLUMN tax_id VARCHAR(80) NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'suppliers'
      AND COLUMN_NAME = 'default_currency'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE suppliers ADD COLUMN default_currency VARCHAR(12) NOT NULL DEFAULT ''KHR''',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'suppliers'
      AND COLUMN_NAME = 'active'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE suppliers ADD COLUMN active BOOLEAN NOT NULL DEFAULT TRUE',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'suppliers'
      AND COLUMN_NAME = 'notes'
);
SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE suppliers ADD COLUMN notes VARCHAR(255) NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS supplier_catalog_items (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    supplier_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    supplier_sku VARCHAR(80) NULL,
    purchase_unit_id BIGINT NULL,
    last_cost DECIMAL(18,2) NULL,
    lead_time_days INT NULL,
    minimum_order_quantity DECIMAL(18,2) NULL,
    pack_size DECIMAL(18,2) NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_supplier_catalog_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    CONSTRAINT fk_supplier_catalog_product FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT fk_supplier_catalog_unit FOREIGN KEY (purchase_unit_id) REFERENCES units(id)
);

CREATE TABLE IF NOT EXISTS purchase_orders (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    supplier_id BIGINT NOT NULL,
    store_id BIGINT NOT NULL,
    status VARCHAR(40) NOT NULL,
    tax_rate DECIMAL(18,4) NOT NULL DEFAULT 0,
    subtotal DECIMAL(18,2) NOT NULL,
    tax_amount DECIMAL(18,2) NOT NULL,
    total_amount DECIMAL(18,2) NOT NULL,
    notes VARCHAR(255) NULL,
    ordered_at TIMESTAMP NULL,
    approved_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_purchase_orders_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    CONSTRAINT fk_purchase_orders_store FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE IF NOT EXISTS purchase_order_lines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    purchase_order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    ordered_quantity DECIMAL(18,2) NOT NULL,
    received_quantity DECIMAL(18,2) NOT NULL DEFAULT 0,
    unit_cost DECIMAL(18,2) NOT NULL,
    line_total DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_purchase_order_lines_order FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id),
    CONSTRAINT fk_purchase_order_lines_product FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE IF NOT EXISTS goods_receipts (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    purchase_order_id BIGINT NOT NULL,
    supplier_id BIGINT NOT NULL,
    store_id BIGINT NOT NULL,
    status VARCHAR(40) NOT NULL,
    notes VARCHAR(255) NULL,
    total_amount DECIMAL(18,2) NOT NULL,
    received_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_goods_receipts_po FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id),
    CONSTRAINT fk_goods_receipts_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    CONSTRAINT fk_goods_receipts_store FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE IF NOT EXISTS goods_receipt_lines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    goods_receipt_id BIGINT NOT NULL,
    purchase_order_line_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    received_quantity DECIMAL(18,2) NOT NULL,
    unit_cost DECIMAL(18,2) NOT NULL,
    line_total DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_goods_receipt_lines_receipt FOREIGN KEY (goods_receipt_id) REFERENCES goods_receipts(id),
    CONSTRAINT fk_goods_receipt_lines_po_line FOREIGN KEY (purchase_order_line_id) REFERENCES purchase_order_lines(id),
    CONSTRAINT fk_goods_receipt_lines_product FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE IF NOT EXISTS supplier_invoices (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    supplier_id BIGINT NOT NULL,
    purchase_order_id BIGINT NULL,
    goods_receipt_id BIGINT NULL,
    status VARCHAR(40) NOT NULL,
    invoice_number VARCHAR(120) NOT NULL,
    invoice_date DATE NOT NULL,
    subtotal DECIMAL(18,2) NOT NULL,
    tax_amount DECIMAL(18,2) NOT NULL,
    total_amount DECIMAL(18,2) NOT NULL,
    paid_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    outstanding_amount DECIMAL(18,2) NOT NULL,
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_supplier_invoices_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    CONSTRAINT fk_supplier_invoices_po FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id),
    CONSTRAINT fk_supplier_invoices_grn FOREIGN KEY (goods_receipt_id) REFERENCES goods_receipts(id)
);

CREATE TABLE IF NOT EXISTS supplier_invoice_lines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    supplier_invoice_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity DECIMAL(18,2) NOT NULL,
    unit_cost DECIMAL(18,2) NOT NULL,
    line_total DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_supplier_invoice_lines_invoice FOREIGN KEY (supplier_invoice_id) REFERENCES supplier_invoices(id),
    CONSTRAINT fk_supplier_invoice_lines_product FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE IF NOT EXISTS supplier_payments (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    supplier_invoice_id BIGINT NOT NULL,
    amount DECIMAL(18,2) NOT NULL,
    paid_at TIMESTAMP NOT NULL,
    reference VARCHAR(120) NULL,
    status VARCHAR(40) NOT NULL,
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_supplier_payments_invoice FOREIGN KEY (supplier_invoice_id) REFERENCES supplier_invoices(id)
);

CREATE TABLE IF NOT EXISTS purchase_returns (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    supplier_id BIGINT NOT NULL,
    goods_receipt_id BIGINT NULL,
    supplier_invoice_id BIGINT NULL,
    store_id BIGINT NOT NULL,
    status VARCHAR(40) NOT NULL,
    return_date DATE NOT NULL,
    total_amount DECIMAL(18,2) NOT NULL,
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_purchase_returns_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    CONSTRAINT fk_purchase_returns_grn FOREIGN KEY (goods_receipt_id) REFERENCES goods_receipts(id),
    CONSTRAINT fk_purchase_returns_invoice FOREIGN KEY (supplier_invoice_id) REFERENCES supplier_invoices(id),
    CONSTRAINT fk_purchase_returns_store FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE IF NOT EXISTS purchase_return_lines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    purchase_return_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity DECIMAL(18,2) NOT NULL,
    unit_cost DECIMAL(18,2) NOT NULL,
    line_total DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_purchase_return_lines_return FOREIGN KEY (purchase_return_id) REFERENCES purchase_returns(id),
    CONSTRAINT fk_purchase_return_lines_product FOREIGN KEY (product_id) REFERENCES products(id)
);
