ALTER TABLE sales
    ADD COLUMN delivery_charge DECIMAL(18,2) NOT NULL DEFAULT 0.00 AFTER payment_terms,
    ADD COLUMN other_charge DECIMAL(18,2) NOT NULL DEFAULT 0.00 AFTER delivery_charge,
    ADD COLUMN deposit_amount DECIMAL(18,2) NOT NULL DEFAULT 0.00 AFTER other_charge;
