-- Create sale_lines table for SaleLine entity
CREATE TABLE IF NOT EXISTS sale_lines (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  sale_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  quantity DECIMAL(18,2) NOT NULL,
  unit_price DECIMAL(18,2) NOT NULL,
  line_discount DECIMAL(18,2) NOT NULL DEFAULT 0,
  line_total DECIMAL(18,2) NOT NULL,
  CONSTRAINT fk_sale_lines_sale FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
  CONSTRAINT fk_sale_lines_product FOREIGN KEY (product_id) REFERENCES products(id),
  INDEX idx_sale_lines_sale_id (sale_id),
  INDEX idx_sale_lines_product_id (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
