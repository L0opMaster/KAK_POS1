-- Create sale_discounts table for SaleDiscount entity
CREATE TABLE IF NOT EXISTS sale_discounts (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  sale_id BIGINT NOT NULL,
  discount_type VARCHAR(20) NOT NULL,
  amount DECIMAL(18,2) NOT NULL,
  reason VARCHAR(255),
  CONSTRAINT fk_sale_discounts_sale FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
  INDEX idx_sale_discounts_sale_id (sale_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
