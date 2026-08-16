ALTER TABLE products ADD COLUMN tax_rate DOUBLE NULL;

UPDATE products SET tax_rate = COALESCE(
  (SELECT tax_rate FROM business_settings ORDER BY id ASC LIMIT 1), 0)
WHERE tax_rate IS NULL;

ALTER TABLE products MODIFY COLUMN tax_rate DOUBLE NOT NULL;
