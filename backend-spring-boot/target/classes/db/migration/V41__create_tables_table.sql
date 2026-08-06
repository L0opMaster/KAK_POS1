-- Create tables table for restaurant table management
CREATE TABLE IF NOT EXISTS tables (
    id BIGINT NOT NULL AUTO_INCREMENT,
    table_number VARCHAR(20) NOT NULL UNIQUE,
    display_name VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    capacity INT NOT NULL DEFAULT 4,
    section VARCHAR(50),
    notes VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    created_by_id BIGINT,
    updated_by_id BIGINT,
    PRIMARY KEY (id),
    INDEX idx_tables_table_number (table_number),
    INDEX idx_tables_status (status),
    INDEX idx_tables_section (section),
    INDEX idx_tables_is_active (is_active),
    FOREIGN KEY (created_by_id) REFERENCES users(id),
    FOREIGN KEY (updated_by_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed some default tables
INSERT INTO tables (table_number, display_name, status, capacity, section, is_active) VALUES
('T1', 'Table 1', 'AVAILABLE', 4, 'INDOOR', TRUE),
('T2', 'Table 2', 'AVAILABLE', 4, 'INDOOR', TRUE),
('T3', 'Table 3', 'AVAILABLE', 4, 'INDOOR', TRUE),
('T4', 'Table 4', 'AVAILABLE', 6, 'INDOOR', TRUE),
('T5', 'Table 5', 'AVAILABLE', 6, 'INDOOR', TRUE),
('O1', 'Outdoor 1', 'AVAILABLE', 4, 'OUTDOOR', TRUE),
('O2', 'Outdoor 2', 'AVAILABLE', 4, 'OUTDOOR', TRUE),
('V1', 'VIP Table', 'AVAILABLE', 8, 'VIP', TRUE);