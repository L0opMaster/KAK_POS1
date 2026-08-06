-- V105: Add estimate/quotation fields to sales table.
-- Supports QuickBooks-style estimate workflow:
--   DRAFT → SENT → ACCEPTED → CONVERTED (to real sale)
--               → DECLINED
--               → EXPIRED

ALTER TABLE sales
  ADD COLUMN estimate_expiry_date      DATE         NULL AFTER deposit_amount,
  ADD COLUMN estimate_sent_at          DATETIME     NULL AFTER estimate_expiry_date,
  ADD COLUMN estimate_accepted_at      DATETIME     NULL AFTER estimate_sent_at,
  ADD COLUMN estimate_declined_at      DATETIME     NULL AFTER estimate_accepted_at,
  ADD COLUMN estimate_decline_reason   VARCHAR(500) NULL AFTER estimate_declined_at,
  ADD COLUMN converted_from_estimate_id BIGINT      NULL AFTER estimate_decline_reason,
  ADD INDEX idx_sales_estimate_status (status, estimate_expiry_date);
