CREATE TABLE purchase_rfqs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    supplier_id BIGINT NULL,
    store_id BIGINT NULL,
    status VARCHAR(40) NOT NULL,
    target_date DATE NULL,
    request_reference VARCHAR(120) NULL,
    notes VARCHAR(500) NULL,
    subtotal DECIMAL(18,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    approved_at TIMESTAMP NULL,
    approved_by_email VARCHAR(150) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_purchase_rfqs_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    CONSTRAINT fk_purchase_rfqs_store FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE purchase_rfq_lines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    purchase_rfq_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    requested_quantity DECIMAL(18,2) NOT NULL,
    estimated_unit_cost DECIMAL(18,2) NOT NULL DEFAULT 0,
    line_total DECIMAL(18,2) NOT NULL DEFAULT 0,
    last_purchase_cost DECIMAL(18,2) NULL,
    line_note VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_purchase_rfq_lines_rfq FOREIGN KEY (purchase_rfq_id) REFERENCES purchase_rfqs(id) ON DELETE CASCADE,
    CONSTRAINT fk_purchase_rfq_lines_product FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE purchase_activities (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    document_type VARCHAR(40) NOT NULL,
    document_id BIGINT NOT NULL,
    action VARCHAR(60) NOT NULL,
    summary VARCHAR(255) NOT NULL,
    actor_email VARCHAR(150) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_purchase_activities_doc (document_type, document_id, created_at)
);
