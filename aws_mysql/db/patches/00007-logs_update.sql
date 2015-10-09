-- liquibase formatted sql
-- changeset l.bird:7
  ALTER TABLE log
  ADD ADJUSTMENT INT;
  -- ROLLBACK ALTER TABLE LOG DROP COLUMN adjustment;