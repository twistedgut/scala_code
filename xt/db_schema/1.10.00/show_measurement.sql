-- Purpose:
-- Product measurements in this table will be shown on the website
--  

BEGIN;


-- Create table for customer_class
CREATE TABLE show_measurement (
	id serial PRIMARY KEY, 
	product_id integer NOT NULL,
    measurement_id integer NOT NULL,
    FOREIGN KEY (product_id) REFERENCES product(id),
    FOREIGN KEY (measurement_id) REFERENCES measurement(id)
);

GRANT ALL ON show_measurement TO www;
GRANT ALL ON show_measurement_id_seq TO www;

-- populate table
INSERT INTO show_measurement (product_id, measurement_id)
    SELECT p.id, m.measurement_id FROM product p
    INNER JOIN product_type_measurement m ON p.product_type_id = m.product_type_id;

COMMIT;
