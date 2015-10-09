-- liquibase formatted sql
-- changeset s.cole:3

CREATE TABLE log (
  id SERIAL PRIMARY KEY,
  reason_id INT NOT NULL REFERENCES reason(id),
  quantity_id INT NOT NULL REFERENCES quantity(id),
  user_name TEXT NOT NULL,
  description TEXT,
  purchase_order TEXT
) ENGINE = INNODB;
-- rollback DROP TABLE log;