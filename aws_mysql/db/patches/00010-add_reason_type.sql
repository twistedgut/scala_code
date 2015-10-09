-- liquibase formatted sql
-- changeset m.esquerra:10

ALTER TABLE reason ADD COLUMN reason_type VARCHAR(50) NOT NULL;
