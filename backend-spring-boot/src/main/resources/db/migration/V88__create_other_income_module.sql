CREATE TABLE other_income_categories (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name_en VARCHAR(120) NOT NULL,
    name_km VARCHAR(120) NOT NULL,
    color VARCHAR(20) DEFAULT '#16a34a',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6)
);

INSERT INTO other_income_categories (name_en, name_km, color, active, created_at) VALUES
('Interest Income', 'ចំណូលការប្រាក់', '#16a34a', true, NOW()),
('Rental Income', 'ចំណូលជួល', '#0ea5e9', true, NOW()),
('Service Income', 'ចំណូលសេវាកម្ម', '#22c55e', true, NOW()),
('Asset Sale', 'ចំណូលលក់ទ្រព្យសកម្ម', '#f59e0b', true, NOW()),
('Other Income', 'ចំណូលផ្សេងៗ', '#64748b', true, NOW());

CREATE TABLE other_incomes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    income_number VARCHAR(30) UNIQUE,
    income_date DATE NOT NULL,
    category_id BIGINT NOT NULL,
    payer_name VARCHAR(160),
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    payment_method VARCHAR(30) NOT NULL DEFAULT 'CASH',
    reference VARCHAR(100),
    note TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    created_by_id BIGINT,
    approved_by_id BIGINT,
    approved_at DATETIME(6),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    CONSTRAINT fk_other_income_category FOREIGN KEY (category_id) REFERENCES other_income_categories(id),
    CONSTRAINT fk_other_income_created_by FOREIGN KEY (created_by_id) REFERENCES users(id),
    CONSTRAINT fk_other_income_approved_by FOREIGN KEY (approved_by_id) REFERENCES users(id)
);

CREATE INDEX idx_other_income_date ON other_incomes(income_date);
CREATE INDEX idx_other_income_category ON other_incomes(category_id);
CREATE INDEX idx_other_income_status ON other_incomes(status);
