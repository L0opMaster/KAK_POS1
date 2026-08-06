-- V103: Add fiscal year prefix to sale document numbers.
-- Changes INV-00019 → INV-2026-00019, SR-00005 → SR-2026-00005, TKT-00001 → TKT-2026-00001
-- Preserves custom/manual references that don't match known generated patterns.

-- Extract year from order_date if available, otherwise use created_at, otherwise current year
UPDATE sales
SET sale_number = CONCAT(
    SUBSTRING_INDEX(sale_number, '-', 1),
    '-',
    CASE
        WHEN order_date IS NOT NULL THEN YEAR(order_date)
        WHEN created_at IS NOT NULL THEN YEAR(created_at)
        ELSE YEAR(CURDATE())
    END,
    '-',
    LPAD(id, 5, '0')
)
WHERE sale_number IS NOT NULL
  AND sale_number != ''
  AND (
    sale_number REGEXP '^INV-[0-9]+$'
    OR sale_number REGEXP '^SALE-[0-9]+$'
    OR sale_number REGEXP '^SR-[0-9]+$'
    OR sale_number REGEXP '^TKT-[0-9]+$'
    OR sale_number REGEXP '^TICKET-[0-9]+$'
    OR sale_number REGEXP '^SO-[0-9]+$'
  );

-- Update PAY-ment references with year prefix
UPDATE payments
SET reference_number = CONCAT(
    SUBSTRING_INDEX(reference_number, '-', 1),
    '-',
    YEAR(CURDATE()),
    '-',
    LPAD(id, 5, '0')
)
WHERE reference_number IS NOT NULL
  AND reference_number != ''
  AND (
    reference_number REGEXP '^PAY-[0-9]+$'
    OR reference_number REGEXP '^COLLECT-[0-9]+$'
  );
