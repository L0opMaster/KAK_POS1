-- V69: Add production order workflow timestamps for DRAFT → IN_PROGRESS → COMPLETED/CANCELLED lifecycle
ALTER TABLE production_orders
    ADD COLUMN started_at    DATETIME NULL AFTER posted_at,
    ADD COLUMN completed_at  DATETIME NULL AFTER started_at,
    ADD COLUMN cancelled_at  DATETIME NULL AFTER completed_at,
    ADD COLUMN cancel_reason VARCHAR(255) NULL AFTER cancelled_at;

-- Migrate existing POSTED orders to COMPLETED (they were immediately posted before this workflow existed)
UPDATE production_orders
SET status       = 'COMPLETED',
    completed_at = posted_at
WHERE status = 'POSTED';
