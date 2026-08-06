-- EOD Owner Report Module Tables
-- End-of-Day snapshots for owner reports

CREATE TABLE eod_snapshots (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    eod_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PROCESSING',
    net_sales_today DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    cash_collected_today DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    new_credit_today DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    total_ar_balance DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    overdue_gt_30_days DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    total_sales_count INT NOT NULL DEFAULT 0,
    total_payments_count INT NOT NULL DEFAULT 0,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    version BIGINT DEFAULT 0,

    INDEX idx_eod_date (eod_date),
    INDEX idx_eod_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE eod_invoice_snapshots (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    eod_snapshot_id BIGINT NOT NULL,
    sale_id BIGINT NOT NULL,
    invoice_no VARCHAR(50),
    invoice_date DATE NOT NULL,
    customer_id BIGINT,
    customer_name VARCHAR(150),
    total_sale DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    paid_amount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    balance DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    days_outstanding INT NOT NULL DEFAULT 0,
    aging_bucket VARCHAR(20),
    payment_status VARCHAR(20),

    FOREIGN KEY (eod_snapshot_id) REFERENCES eod_snapshots(id) ON DELETE CASCADE,
    FOREIGN KEY (sale_id) REFERENCES sales(id),
    FOREIGN KEY (customer_id) REFERENCES customers(id),

    INDEX idx_eod_invoice_snapshot (eod_snapshot_id),
    INDEX idx_eod_invoice_sale (sale_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE eod_collection_summaries (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    eod_snapshot_id BIGINT NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    total_amount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    transaction_count INT NOT NULL DEFAULT 0,

    FOREIGN KEY (eod_snapshot_id) REFERENCES eod_snapshots(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE eod_aging_summaries (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    eod_snapshot_id BIGINT NOT NULL,
    aging_bucket VARCHAR(20) NOT NULL,
    total_balance DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    invoice_count INT NOT NULL DEFAULT 0,

    FOREIGN KEY (eod_snapshot_id) REFERENCES eod_snapshots(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE eod_customer_credits (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    eod_snapshot_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    customer_name VARCHAR(150),
    credit_limit DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    current_balance DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20),

    FOREIGN KEY (eod_snapshot_id) REFERENCES eod_snapshots(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;