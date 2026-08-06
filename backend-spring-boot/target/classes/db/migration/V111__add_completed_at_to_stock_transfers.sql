-- StockTransfer.completedAt is mapped to stock_transfers.completed_at, but no
-- prior migration ever created the column, so every transfer list/complete
-- call fails with "Unknown column 'st1_0.completed_at' in 'field list'".
ALTER TABLE stock_transfers
  ADD COLUMN completed_at TIMESTAMP NULL AFTER notes;
