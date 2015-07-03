-- liquibase formatted sql
-- changeset j.maslen:1

CREATE TABLE box (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    dc_id INT NOT NULL REFERENCES dc(id),
    UNIQUE KEY uq_box_dc (code, name, dc_id)
);
-- rollback DROP TABLE box;

CREATE TABLE business (
  id SERIAL PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL UNIQUE
);
-- rollback DROP TABLE business;

CREATE TABLE link_business__box (
  id SERIAL PRIMARY KEY,
  box_id INT NOT NULL REFERENCES box(id),
  business_id INT NOT NULL REFERENCES business(id),
  UNIQUE KEY uq_business_box (box_id, business_id)
);
-- rollback DROP TABLE link_business__box;

CREATE TABLE quantity (
    id SERIAL PRIMARY KEY,
    box_id INT NOT NULL REFERENCES box(id) UNIQUE,
    quantity INT
);
-- rollback DROP TABLE quantity;


CREATE TABLE dc (
  id SERIAL PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  name VARCHAR(10) NOT NULL UNIQUE
);
-- rollback DROP TABLE dc;
