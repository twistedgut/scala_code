-- liquibase formatted sql
-- changeset l.bird:4
  ALTER TABLE log
  ADD start_quantity INT,
  ADD date_added TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;
  -- rollback ALTER TABLE log DROP COLUMN start_quantity, DROP COLUMN date_added;