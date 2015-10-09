-- liquibase formatted sql
-- changeset a.todd:9

ALTER TABLE box ADD COLUMN reorder_threshold INT;
