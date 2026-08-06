-- Update existing products to NOT track inventory by default
UPDATE products SET track_inventory = FALSE WHERE active = TRUE;