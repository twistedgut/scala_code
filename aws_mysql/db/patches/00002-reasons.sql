-- liquibase formatted sql
-- changeset l.bird:2

CREATE TABLE reason (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  code VARCHAR(100) NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL,
  is_positive BOOLEAN NOT NULL
) ENGINE = INNODB;
-- rollback DROP TABLE reason;
