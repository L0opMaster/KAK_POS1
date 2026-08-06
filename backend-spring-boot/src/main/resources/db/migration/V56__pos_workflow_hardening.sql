ALTER TABLE shifts
    ADD COLUMN store_id BIGINT NULL AFTER approved_by_id;

ALTER TABLE shifts
    ADD CONSTRAINT fk_shifts_store
        FOREIGN KEY (store_id) REFERENCES stores(id);

UPDATE shifts s
JOIN stores st ON st.id = (
    SELECT s2.id
    FROM stores s2
    ORDER BY s2.id
    LIMIT 1
)
SET s.store_id = st.id
WHERE s.store_id IS NULL;

ALTER TABLE payments
    ADD COLUMN shift_id BIGINT NULL AFTER sale_id;

ALTER TABLE payments
    ADD CONSTRAINT fk_payments_shift
        FOREIGN KEY (shift_id) REFERENCES shifts(id);

UPDATE payments p
JOIN sales s ON s.id = p.sale_id
SET p.shift_id = s.shift_id
WHERE p.sale_id IS NOT NULL
  AND p.shift_id IS NULL;

