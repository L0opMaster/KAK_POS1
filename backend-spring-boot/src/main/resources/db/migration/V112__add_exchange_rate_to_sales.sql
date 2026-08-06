ALTER TABLE sales ADD COLUMN exchange_rate_khr DECIMAL(18,6) NULL;

-- Backfill existing sales with today's KHR rate so old receipts still show
-- a sensible figure instead of blank; new sales get their own snapshot going
-- forward from CurrencySetting("KHR").exchangeRate at creation time.
UPDATE sales s
JOIN currencies c ON c.code = 'KHR'
SET s.exchange_rate_khr = c.exchange_rate
WHERE s.exchange_rate_khr IS NULL;
