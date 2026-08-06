-- V104: Create recurring invoice templates table.
-- Stores templates for auto-generating invoices on a schedule.

CREATE TABLE recurring_invoice_templates (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,

    -- Template identity
    name            VARCHAR(150)    NOT NULL COMMENT 'User-friendly template name',
    description     VARCHAR(500)    NULL COMMENT 'Optional description',

    -- Scheduling
    frequency       VARCHAR(20)     NOT NULL COMMENT 'DAILY | WEEKLY | MONTHLY | YEARLY',
    interval_count  INT             NOT NULL DEFAULT 1 COMMENT 'Every N days/weeks/months/years',
    day_of_week     INT             NULL COMMENT '0=Sun..6=Sat (for WEEKLY)',
    day_of_month    INT             NULL COMMENT '1-31 (for MONTHLY/YEARLY)',
    month_of_year   INT             NULL COMMENT '1-12 (for YEARLY)',
    next_run_date   DATE            NOT NULL COMMENT 'Next scheduled generation date',
    end_date        DATE            NULL COMMENT 'Optional end date for the recurrence',
    max_occurrences INT             NULL COMMENT 'Maximum number of invoices to generate',
    occurrences_count INT           NOT NULL DEFAULT 0 COMMENT 'How many invoices have been generated so far',

    -- Invoice template data (copied when generating)
    customer_id     BIGINT          NULL COMMENT 'FK to customers',
    display_name    VARCHAR(120)    NULL COMMENT 'Order display name template',
    payment_terms   VARCHAR(60)     NULL DEFAULT 'CASH',
    delivery_charge DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    other_charge    DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    deposit_amount  DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    note            VARCHAR(500)    NULL,
    invoice_discount DECIMAL(18,2)  NOT NULL DEFAULT 0.00,
    tax_rate        DOUBLE          NOT NULL DEFAULT 0.0,
    delivery_recipient_name VARCHAR(150) NULL,
    delivery_phone  VARCHAR(50)     NULL,
    delivery_address VARCHAR(255)   NULL,

    -- Lines stored as JSON for simplicity
    lines_json      LONGTEXT        NOT NULL COMMENT 'JSON array of line items',

    -- Status
    active          BOOLEAN         NOT NULL DEFAULT TRUE,
    last_generated_at TIMESTAMP     NULL,
    last_invoice_id BIGINT          NULL COMMENT 'FK to sales table (last generated invoice)',

    PRIMARY KEY (id),
    INDEX idx_recurring_active_next (active, next_run_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
