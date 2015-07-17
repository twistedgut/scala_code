
-- Purpose:
--  

BEGIN;


-- Create table for customer_class
CREATE TABLE customer_class (
	id serial PRIMARY KEY, 
	class varchar(255) NOT NULL UNIQUE,
    is_visible boolean NOT NULL DEFAULT TRUE
	);

GRANT ALL ON customer_class TO www;
GRANT ALL ON customer_class_id_seq TO www;

-- populate table
INSERT INTO customer_class (class) VALUES ('None');
INSERT INTO customer_class (class) VALUES ('EIP');
INSERT INTO customer_class (class) VALUES ('IP');
INSERT INTO customer_class (class) VALUES ('Hot Contact');
INSERT INTO customer_class (class) VALUES ('PR');
INSERT INTO customer_class (class) VALUES ('Staff');

-- add is_visible field to customer_category
ALTER TABLE customer_category ADD COLUMN is_visible boolean NOT NULL DEFAULT TRUE;

-- add category_class_id
ALTER TABLE customer_category ADD COLUMN customer_class_id integer NOT NULL DEFAULT 0;

-- make customer_category name unique
ALTER TABLE customer_category ADD CONSTRAINT customer_category_category_key UNIQUE (category);

-- populate with customer_class id
UPDATE customer_category SET customer_class_id = 1 WHERE id = 1;
UPDATE customer_category SET customer_class_id = 6 WHERE id = 2;
UPDATE customer_category SET customer_class_id = 2 WHERE id = 4;
UPDATE customer_category SET customer_class_id = 1 WHERE id = 5;
UPDATE customer_category SET customer_class_id = 5 WHERE id = 6;
UPDATE customer_category SET customer_class_id = 1 WHERE id = 12;
UPDATE customer_category SET customer_class_id = 6 WHERE id = 13;
UPDATE customer_category SET customer_class_id = 4 WHERE id = 14;
UPDATE customer_category SET customer_class_id = 6 WHERE id = 15;
UPDATE customer_category SET customer_class_id = 2 WHERE id = 16;
UPDATE customer_category SET customer_class_id = 2 WHERE id = 17;
UPDATE customer_category SET customer_class_id = 6 WHERE id = 18;
UPDATE customer_category SET customer_class_id = 5 WHERE id = 19;
UPDATE customer_category SET customer_class_id = 5 WHERE id = 20;
UPDATE customer_category SET customer_class_id = 5 WHERE id = 22;
UPDATE customer_category SET customer_class_id = 2 WHERE id = 23;
UPDATE customer_category SET customer_class_id = 2 WHERE id = 24;
UPDATE customer_category SET customer_class_id = 3 WHERE id = 25;

UPDATE customer_category SET customer_class_id = (SELECT id FROM
    customer_class WHERE class='None') WHERE customer_class_id = 0;

-- set foreign key
ALTER TABLE customer_category ADD FOREIGN KEY (customer_class_id) REFERENCES customer_class(id);

COMMIT;
