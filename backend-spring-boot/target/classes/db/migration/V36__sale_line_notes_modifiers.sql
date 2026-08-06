ALTER TABLE sale_lines
  ADD COLUMN line_note VARCHAR(500) NULL AFTER line_total,
  ADD COLUMN modifier_summary VARCHAR(512) NULL AFTER line_note,
  ADD COLUMN modifier_data LONGTEXT NULL AFTER modifier_summary;
