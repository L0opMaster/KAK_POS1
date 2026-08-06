-- V18__add_category_parent.sql
-- Add parent_id column to categories table to support category hierarchy

ALTER TABLE categories
ADD COLUMN parent_id BIGINT AFTER id,
ADD CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL;
