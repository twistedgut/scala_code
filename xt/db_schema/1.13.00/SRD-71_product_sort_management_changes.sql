/**************************************
* SRD-71: product sort management
*
* Revised data structure
* 
**************************************/

BEGIN;

/***********************
* DROP old sort table
***********************/
DROP TABLE product.pws_sort;



/********************
* CREATE new tables
********************/

CREATE TABLE product.pws_sort_variable (
    id serial PRIMARY KEY,
    name varchar(50) NOT NULL,
    description varchar(255) NOT NULL,
    created timestamp without time zone NOT NULL DEFAULT now(),
    created_by integer NOT NULL REFERENCES operator(id),
    UNIQUE (name)
);
GRANT ALL ON product.pws_sort_variable TO www;
GRANT ALL ON product.pws_sort_variable_id_seq TO www;

INSERT INTO product.pws_sort_variable (id, name, description, created_by)
    VALUES (1, 'available_to_sell', 'Available to Sell', (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable (id, name, description, created_by)
    VALUES (2, 'inverse_upload_days', 'Age Factor', (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable (id, name, description, created_by)
    VALUES (3, 'pcnt_sizes_in_stock', '% Sizes in Stock', (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable (id, name, description, created_by)
    VALUES (4, 'price', 'Price', (SELECT id FROM operator WHERE name = 'Tim Gagen'));
SELECT setval('product.pws_sort_variable_id_seq', (SELECT max(id) FROM product.pws_sort_variable));



CREATE TABLE product.pws_sort_destination (
    id serial PRIMARY KEY,
    name varchar(50) NOT NULL
);
GRANT ALL ON product.pws_sort_destination TO www;
GRANT ALL ON product.pws_sort_destination_id_seq TO www;

INSERT INTO product.pws_sort_destination (id, name) VALUES (1, 'main');
INSERT INTO product.pws_sort_destination (id, name) VALUES (2, 'preview');
SELECT setval('product.pws_sort_destination_id_seq', (SELECT max(id) FROM product.pws_sort_destination));



CREATE TABLE product.pws_sort_variable_weighting (
    id serial PRIMARY KEY,
    pws_sort_variable_id integer NOT NULL REFERENCES product.pws_sort_variable(id),
    relative_weighting numeric NOT NULL,
    pws_sort_destination_id integer NOT NULL REFERENCES product.pws_sort_destination(id),
    created timestamp without time zone NOT NULL DEFAULT now(),
    created_by integer NOT NULL REFERENCES operator(id)
);
CREATE INDEX ix_pws_sort_variable_weighting__pws_sort_variable_id ON product.pws_sort_variable_weighting(pws_sort_variable_id);
CREATE INDEX ix_pws_sort_variable_weighting__pws_sort_destination_id ON product.pws_sort_variable_weighting(pws_sort_destination_id);
CREATE INDEX ix_pws_sort_variable_weighting__created_by ON product.pws_sort_variable_weighting(created_by);
GRANT ALL ON product.pws_sort_variable_weighting TO www;
GRANT ALL ON product.pws_sort_variable_weighting_id_seq TO www;

INSERT INTO product.pws_sort_variable_weighting (id, pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by)
    VALUES (1, 1, 100, (SELECT id FROM product.pws_sort_destination WHERE name = 'preview'), (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable_weighting (id, pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by)
    VALUES (2, 2, 100, (SELECT id FROM product.pws_sort_destination WHERE name = 'preview'), (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable_weighting (id, pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by)
    VALUES (3, 3, 100, (SELECT id FROM product.pws_sort_destination WHERE name = 'preview'), (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable_weighting (id, pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by)
    VALUES (4, 4, 100, (SELECT id FROM product.pws_sort_destination WHERE name = 'preview'), (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable_weighting (id, pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by)
    VALUES (5, 1, 100, (SELECT id FROM product.pws_sort_destination WHERE name = 'main'), (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable_weighting (id, pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by)
    VALUES (6, 2, 100, (SELECT id FROM product.pws_sort_destination WHERE name = 'main'), (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable_weighting (id, pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by)
    VALUES (7, 3, 100, (SELECT id FROM product.pws_sort_destination WHERE name = 'main'), (SELECT id FROM operator WHERE name = 'Tim Gagen'));
INSERT INTO product.pws_sort_variable_weighting (id, pws_sort_variable_id, relative_weighting, pws_sort_destination_id, created_by)
    VALUES (8, 4, 100, (SELECT id FROM product.pws_sort_destination WHERE name = 'main'), (SELECT id FROM operator WHERE name = 'Tim Gagen'));
SELECT setval('product.pws_sort_variable_weighting_id_seq', (SELECT max(id) FROM product.pws_sort_variable_weighting));



CREATE TABLE product.pws_product_sort_variable_value (
    product_id integer NOT NULL REFERENCES product(id),
    pws_sort_variable_id integer NOT NULL REFERENCES product.pws_sort_variable(id),
    pws_sort_destination_id integer NOT NULL REFERENCES product.pws_sort_destination(id),
    actual_value numeric NOT NULL,
    weighted_value numeric NOT NULL,
    created timestamp without time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (product_id, pws_sort_variable_id, pws_sort_destination_id)
);
CREATE INDEX ix_pws_product_sort_variable_value__product_id ON product.pws_product_sort_variable_value(product_id);
CREATE INDEX ix_pws_product_sort_variable_value__pws_sort_variable_id ON product.pws_product_sort_variable_value(pws_sort_variable_id);
CREATE INDEX ix_pws_product_sort_variable_value__pws_sort_destination_id ON product.pws_product_sort_variable_value(pws_sort_destination_id);
GRANT ALL ON product.pws_product_sort_variable_value TO www;



CREATE TABLE product.pws_sort_order (
    product_id integer REFERENCES product(id),
    pws_sort_destination_id integer NOT NULL REFERENCES product.pws_sort_destination(id),
    score numeric NOT NULL,
    score_offset numeric NOT NULL,
    sort_order integer NOT NULL,
    created timestamp without time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (product_id, pws_sort_destination_id)
);
CREATE INDEX ix_pws_sort_order__product_id ON product.pws_sort_order(product_id);
CREATE INDEX ix_pws_sort_order__pws_sort_destination_id ON product.pws_sort_order(pws_sort_destination_id);
CREATE INDEX ix_pws_sort_order__score ON product.pws_sort_order(score);
CREATE UNIQUE INDEX uix_pws_sort_order__sort_order ON product.pws_sort_order(pws_sort_destination_id, sort_order);
GRANT ALL ON product.pws_sort_order TO www;


COMMIT;

