-- V49: held ticket split/merge/move/assign + predefined ticket tables

SET @db_name = DATABASE();

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'sales' AND COLUMN_NAME = 'display_name');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE sales ADD COLUMN display_name VARCHAR(120) NULL AFTER note', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'sales' AND COLUMN_NAME = 'comment');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE sales ADD COLUMN comment VARCHAR(512) NULL AFTER display_name', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'sales' AND COLUMN_NAME = 'assigned_employee_id');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE sales ADD COLUMN assigned_employee_id BIGINT NULL AFTER voided_by_id', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'sales' AND COLUMN_NAME = 'predefined_ticket_id');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE sales ADD COLUMN predefined_ticket_id BIGINT NULL AFTER assigned_employee_id', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'sales' AND COLUMN_NAME = 'closed_reason');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE sales ADD COLUMN closed_reason VARCHAR(20) NULL AFTER status', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @db_name AND TABLE_NAME = 'sales' AND COLUMN_NAME = 'terminal_id');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE sales ADD COLUMN terminal_id VARCHAR(80) NULL AFTER client_ref', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_sales_assigned_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND INDEX_NAME = 'idx_sales_assigned_employee'
);
SET @sql := IF(
    @idx_sales_assigned_exists = 0,
    'CREATE INDEX idx_sales_assigned_employee ON sales(assigned_employee_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_sales_predefined_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND INDEX_NAME = 'idx_sales_predefined_ticket'
);
SET @sql := IF(
    @idx_sales_predefined_exists = 0,
    'CREATE INDEX idx_sales_predefined_ticket ON sales(predefined_ticket_id, status)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS predefined_tickets (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    store_id VARCHAR(80) NOT NULL,
    terminal_id VARCHAR(80) NULL,
    name VARCHAR(120) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL
);

SET @idx_predefined_scope_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'predefined_tickets'
      AND INDEX_NAME = 'idx_predefined_scope'
);
SET @sql := IF(
    @idx_predefined_scope_exists = 0,
    'CREATE INDEX idx_predefined_scope ON predefined_tickets(store_id, terminal_id, active, sort_order)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS ticket_operation_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    ticket_id BIGINT NOT NULL,
    action VARCHAR(40) NOT NULL,
    actor_user_id BIGINT NULL,
    idempotency_key VARCHAR(120) NULL,
    payload_json LONGTEXT NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_ticket_operation_ticket FOREIGN KEY (ticket_id) REFERENCES sales(id),
    CONSTRAINT fk_ticket_operation_actor FOREIGN KEY (actor_user_id) REFERENCES users(id)
);

SET @idx_ticket_op_ticket_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'ticket_operation_log'
      AND INDEX_NAME = 'idx_ticket_operation_ticket'
);
SET @sql := IF(
    @idx_ticket_op_ticket_exists = 0,
    'CREATE INDEX idx_ticket_operation_ticket ON ticket_operation_log(ticket_id, created_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_ticket_op_idem_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'ticket_operation_log'
      AND INDEX_NAME = 'idx_ticket_operation_idempotency'
);
SET @sql := IF(
    @idx_ticket_op_idem_exists = 0,
    'CREATE INDEX idx_ticket_operation_idempotency ON ticket_operation_log(action, idempotency_key)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_sales_assigned_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND CONSTRAINT_NAME = 'fk_sales_assigned_employee'
);
SET @sql := IF(
    @fk_sales_assigned_exists = 0,
    'ALTER TABLE sales ADD CONSTRAINT fk_sales_assigned_employee FOREIGN KEY (assigned_employee_id) REFERENCES users(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_sales_predefined_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND CONSTRAINT_NAME = 'fk_sales_predefined_ticket'
);
SET @sql := IF(
    @fk_sales_predefined_exists = 0,
    'ALTER TABLE sales ADD CONSTRAINT fk_sales_predefined_ticket FOREIGN KEY (predefined_ticket_id) REFERENCES predefined_tickets(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
