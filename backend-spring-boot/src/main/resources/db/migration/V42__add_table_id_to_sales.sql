-- Add shift_id and table_id columns to sales table for proper shift and table management
ALTER TABLE sales ADD COLUMN shift_id BIGINT NULL;
ALTER TABLE sales ADD COLUMN table_id BIGINT NULL;
ALTER TABLE sales ADD CONSTRAINT fk_sales_shift_id FOREIGN KEY (shift_id) REFERENCES shifts(id);
ALTER TABLE sales ADD CONSTRAINT fk_sales_table_id FOREIGN KEY (table_id) REFERENCES tables(id);