CREATE TABLE IF NOT EXISTS stock_transfers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    from_store_id BIGINT NOT NULL,
    to_store_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_legacy_stock_transfers_from_store FOREIGN KEY (from_store_id) REFERENCES stores(id),
    CONSTRAINT fk_legacy_stock_transfers_to_store FOREIGN KEY (to_store_id) REFERENCES stores(id)
);

CREATE TABLE IF NOT EXISTS stock_transfer_lines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    transfer_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity DECIMAL(18,2) NOT NULL,
    CONSTRAINT fk_legacy_stock_transfer_lines_transfer FOREIGN KEY (transfer_id) REFERENCES stock_transfers(id) ON DELETE CASCADE,
    CONSTRAINT fk_legacy_stock_transfer_lines_product FOREIGN KEY (product_id) REFERENCES products(id)
);
