-- V67: Add minimum order quantity to price list items (for wholesale enforcement)
ALTER TABLE price_list_items
    ADD COLUMN minimum_order_qty DECIMAL(18, 4) NULL
        COMMENT 'Wholesale minimum order quantity; NULL means no minimum enforced';
