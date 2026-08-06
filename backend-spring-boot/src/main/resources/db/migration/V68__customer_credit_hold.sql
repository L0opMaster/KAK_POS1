-- V68: Add credit hold flag to customers (manual block for new credit sales)
ALTER TABLE customers
    ADD COLUMN credit_hold TINYINT(1) NOT NULL DEFAULT 0
        COMMENT '1 = manually blocked from new credit sales regardless of limit';
