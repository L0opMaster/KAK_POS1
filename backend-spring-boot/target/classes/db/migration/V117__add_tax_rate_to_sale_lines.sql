ALTER TABLE sale_lines ADD COLUMN tax_rate DOUBLE NULL;

-- Backfill each historical line from its own sale's rate — the old system
-- applied exactly one blended rate per sale, so this is an accurate
-- reconstruction of what was actually charged on that line.
UPDATE sale_lines sl
JOIN sales s ON s.id = sl.sale_id
SET sl.tax_rate = s.tax_rate
WHERE sl.tax_rate IS NULL;

ALTER TABLE sale_lines MODIFY COLUMN tax_rate DOUBLE NOT NULL;
