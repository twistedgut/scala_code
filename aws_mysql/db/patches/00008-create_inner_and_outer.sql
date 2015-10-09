-- liquibase formatted sql
-- changeset s.cole:8

CREATE TABLE innerBoxes (
  id SERIAL PRIMARY KEY,
  box_id INT UNIQUE NOT NULL REFERENCES box(id),
  is_active BOOLEAN DEFAULT FALSE NOT NULL
) ENGINE = INNODB;
-- rollback DROP TABLE inner;

CREATE TABLE outerBoxes (
  id SERIAL PRIMARY KEY,
  box_id INT UNIQUE NOT NULL REFERENCES box(id),
  is_active BOOLEAN DEFAULT FALSE NOT NULL
) ENGINE = INNODB;
-- rollback DROP TABLE outer;

INSERT INTO innerBoxes (box_id) SELECT id FROM box;
INSERT INTO outerBoxes (box_id) SELECT id FROM box;