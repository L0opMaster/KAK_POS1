-- Create cash_events table for auditable cash movement tracking
CREATE TABLE IF NOT EXISTS cash_events (
    id BIGINT NOT NULL AUTO_INCREMENT,
    shift_id BIGINT NOT NULL,
    sale_id BIGINT NULL,
    user_id BIGINT NULL,
    type VARCHAR(30) NOT NULL,
    amount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    reason VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_cash_event_shift (shift_id),
    INDEX idx_cash_event_created (created_at),
    CONSTRAINT fk_cash_event_shift FOREIGN KEY (shift_id) REFERENCES shifts(id),
    CONSTRAINT fk_cash_event_sale FOREIGN KEY (sale_id) REFERENCES sales(id),
    CONSTRAINT fk_cash_event_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
