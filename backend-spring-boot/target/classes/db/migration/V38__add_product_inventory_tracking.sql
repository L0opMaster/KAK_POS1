-- Add track_inventory field to products table
ALTER TABLE products
ADD COLUMN track_inventory BOOLEAN NOT NULL DEFAULT FALSE;