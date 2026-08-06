CREATE TABLE production_recipes (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(150) NOT NULL,
    output_product_id BIGINT NOT NULL,
    output_quantity DECIMAL(18,2) NOT NULL,
    active BIT NOT NULL DEFAULT b'1',
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_production_recipes_output_product FOREIGN KEY (output_product_id) REFERENCES products(id)
);

CREATE TABLE production_recipe_lines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    recipe_id BIGINT NOT NULL,
    component_product_id BIGINT NOT NULL,
    component_quantity DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_production_recipe_lines_recipe FOREIGN KEY (recipe_id) REFERENCES production_recipes(id),
    CONSTRAINT fk_production_recipe_lines_component FOREIGN KEY (component_product_id) REFERENCES products(id)
);

CREATE TABLE production_orders (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    recipe_id BIGINT NOT NULL,
    store_id BIGINT NOT NULL,
    status VARCHAR(40) NOT NULL,
    planned_quantity DECIMAL(18,2) NOT NULL,
    produced_quantity DECIMAL(18,2) NOT NULL,
    waste_quantity DECIMAL(18,2) NOT NULL DEFAULT 0,
    posted_at TIMESTAMP NULL,
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_production_orders_recipe FOREIGN KEY (recipe_id) REFERENCES production_recipes(id),
    CONSTRAINT fk_production_orders_store FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE production_order_lines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    production_order_id BIGINT NOT NULL,
    component_product_id BIGINT NOT NULL,
    planned_quantity DECIMAL(18,2) NOT NULL,
    consumed_quantity DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_production_order_lines_order FOREIGN KEY (production_order_id) REFERENCES production_orders(id),
    CONSTRAINT fk_production_order_lines_component FOREIGN KEY (component_product_id) REFERENCES products(id)
);

CREATE TABLE delivery_notes (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    note_number VARCHAR(60) NOT NULL UNIQUE,
    sale_id BIGINT NOT NULL,
    customer_id BIGINT NULL,
    status VARCHAR(40) NOT NULL,
    delivery_date DATE NOT NULL,
    contact_name VARCHAR(150) NULL,
    contact_phone VARCHAR(50) NULL,
    delivery_address VARCHAR(255) NULL,
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_delivery_notes_sale FOREIGN KEY (sale_id) REFERENCES sales(id),
    CONSTRAINT fk_delivery_notes_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
);

CREATE TABLE delivery_note_lines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    delivery_note_id BIGINT NOT NULL,
    sale_line_id BIGINT NOT NULL,
    quantity DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_delivery_note_lines_note FOREIGN KEY (delivery_note_id) REFERENCES delivery_notes(id),
    CONSTRAINT fk_delivery_note_lines_sale_line FOREIGN KEY (sale_line_id) REFERENCES sale_lines(id)
);
