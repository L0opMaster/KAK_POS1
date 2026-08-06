CREATE TABLE IF NOT EXISTS payment_methods (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(80) NOT NULL,
    display_order INT NOT NULL DEFAULT 0,
    is_cash BOOLEAN NOT NULL DEFAULT FALSE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS currencies (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(12) NOT NULL UNIQUE,
    name VARCHAR(60) NOT NULL,
    symbol VARCHAR(12) NOT NULL,
    exchange_rate DECIMAL(18, 6) NOT NULL DEFAULT 1.000000,
    display_order INT NOT NULL DEFAULT 0,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @pm_display_order_exists := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'payment_methods'
    AND COLUMN_NAME = 'display_order'
);
SET @pm_display_order_sql := IF(
  @pm_display_order_exists = 0,
  'ALTER TABLE payment_methods ADD COLUMN display_order INT NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt FROM @pm_display_order_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @pm_cash_exists := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'payment_methods'
    AND COLUMN_NAME = 'is_cash'
);
SET @pm_cash_sql := IF(
  @pm_cash_exists = 0,
  'ALTER TABLE payment_methods ADD COLUMN is_cash BOOLEAN NOT NULL DEFAULT FALSE',
  'SELECT 1'
);
PREPARE stmt FROM @pm_cash_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @pm_created_exists := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'payment_methods'
    AND COLUMN_NAME = 'created_at'
);
SET @pm_created_sql := IF(
  @pm_created_exists = 0,
  'ALTER TABLE payment_methods ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
  'SELECT 1'
);
PREPARE stmt FROM @pm_created_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @pm_updated_exists := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'payment_methods'
    AND COLUMN_NAME = 'updated_at'
);
SET @pm_updated_sql := IF(
  @pm_updated_exists = 0,
  'ALTER TABLE payment_methods ADD COLUMN updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
  'SELECT 1'
);
PREPARE stmt FROM @pm_updated_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

INSERT INTO payment_methods (code, name, display_order, is_cash, active)
VALUES
  ('CASH', 'Cash', 10, TRUE, TRUE),
  ('CARD', 'Card', 20, FALSE, TRUE),
  ('BANK_TRANSFER', 'Bank Transfer', 30, FALSE, TRUE),
  ('MOBILE_WALLET', 'Mobile Wallet', 40, FALSE, TRUE)
AS incoming_payment_method
ON DUPLICATE KEY UPDATE
  name = incoming_payment_method.name,
  display_order = incoming_payment_method.display_order,
  is_cash = incoming_payment_method.is_cash,
  active = incoming_payment_method.active;

INSERT INTO currencies (code, name, symbol, exchange_rate, display_order, is_default, active)
VALUES
  ('KHR', 'Khmer Riel', '៛', 1.000000, 10, TRUE, TRUE),
  ('USD', 'US Dollar', '$', 0.000244, 20, FALSE, TRUE)
AS incoming_currency
ON DUPLICATE KEY UPDATE
  name = incoming_currency.name,
  symbol = incoming_currency.symbol,
  exchange_rate = incoming_currency.exchange_rate,
  display_order = incoming_currency.display_order,
  active = incoming_currency.active;
