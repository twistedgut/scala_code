-- fix stuff that needs fixing before the patch can be applied
BEGIN;
    -- product
    UPDATE product
    SET sub_type_id = (select min(id) from sub_type where sub_type='Cropped')
    WHERE sub_type_id=(select max(id) from sub_type where sub_type='Cropped');
    -- product_classification_structure
    UPDATE product_classification_structure
    SET sub_type_id = (select min(id) from sub_type where sub_type='Cropped')
    WHERE sub_type_id=(select max(id) from sub_type where sub_type='Cropped');

    -- duplicate sub type
    DELETE FROM sub_type WHERE id=(select max(id) from sub_type where sub_type='Cropped');
    -- make sure it never happens again
    ALTER TABLE sub_type ADD UNIQUE(sub_type);
COMMIT;


-- new schema for website category navigation management
BEGIN;

-- attribute type lookup table
CREATE TABLE product.attribute_type (
	id serial primary key,
	name varchar(255) not null unique,
	web_attribute varchar(255) not null,
	navigational boolean not null default false
);

-- make sure www can use the table
GRANT ALL ON product.attribute_type TO www;
GRANT ALL ON product.attribute_type_id_seq TO www;

-- populate lookup table
INSERT INTO product.attribute_type VALUES (0, 'None', 'NONE', true);
INSERT INTO product.attribute_type VALUES (1, 'Classification', 'NAV_LEVEL1', true);
INSERT INTO product.attribute_type VALUES (2, 'Product Type', 'NAV_LEVEL2', true);
INSERT INTO product.attribute_type VALUES (3, 'Sub-Type', 'NAV_LEVEL3', true);
INSERT INTO product.attribute_type VALUES (4, 'Hierarchy', 'NAV_LEVEL3', false);
INSERT INTO product.attribute_type VALUES (5, 'Custom List', 'CUSTOM_LIST', false);
INSERT INTO product.attribute_type VALUES (6, E'What\'s New', 'WHATS_NEW', false);
INSERT INTO product.attribute_type VALUES (7, E'What\'s Hot', 'WHATS_HOT', false);
INSERT INTO product.attribute_type VALUES (8, 'Slug Image', 'SLUG_IMAGE', false);
INSERT INTO product.attribute_type VALUES (9, 'Designer', 'DESIGNER', true);


-- attribute table
CREATE TABLE product.attribute (
	id serial primary key,
	name varchar(255) not null,
	attribute_type_id integer null references product.attribute_type(id),
	deleted boolean not null default false,
	synonyms varchar(255) null,
	manual_sort boolean null default false,
	UNIQUE (name, attribute_type_id)
);

-- make sure www can use the table
GRANT ALL ON product.attribute TO www;
GRANT ALL ON product.attribute_id_seq TO www;

-- populate attribute table
INSERT INTO product.attribute (id, name, attribute_type_id) VALUES(default, 'Shop', 0);

INSERT INTO product.attribute (name, attribute_type_id) (SELECT replace(classification, ' ', '_'), 1 FROM classification);
INSERT INTO product.attribute (name, attribute_type_id) (SELECT replace(product_type, ' ', '_'), 2 FROM product_type);
INSERT INTO product.attribute (name, attribute_type_id) (SELECT replace(sub_type, ' ', '_'), 3 FROM sub_type);



-- attribute value table
CREATE TABLE product.attribute_value (
	id serial primary key,
	product_id integer null references product(id),
	attribute_id integer null references product.attribute(id),
	deleted boolean not null default false,
	sort_order integer not null default 0,
	UNIQUE (product_id, attribute_id)
);

-- make sure www can use the table
GRANT ALL ON product.attribute_value TO www;
GRANT ALL ON product.attribute_value_id_seq TO www;

-- populate table
INSERT INTO product.attribute_value (product_id, attribute_id) (SELECT p.id, cat.id FROM product p, classification c, product.attribute cat where p.classification_id = c.id and replace(c.classification, ' ', '_') = cat.name and cat.attribute_type_id = 1);
INSERT INTO product.attribute_value (product_id, attribute_id) (SELECT p.id, cat.id FROM product p, product_type pt, product.attribute cat where p.product_type_id = pt.id and replace(pt.product_type, ' ', '_') = cat.name and cat.attribute_type_id = 2);
INSERT INTO product.attribute_value (product_id, attribute_id) (SELECT p.id, cat.id FROM product p, sub_type st, product.attribute cat where p.sub_type_id = st.id and replace(st.sub_type, ' ', '_') = cat.name and cat.attribute_type_id = 3);



-- category navigation tree
CREATE TABLE product.navigation_tree (
	id serial primary key,
	attribute_id integer not null references product.attribute(id),
	parent_id integer null references product.navigation_tree(id),
	sort_order integer not null default 0,
	visible boolean not null default false,
	deleted boolean not null default false,
	feature_product_id integer null references product(id),
	feature_product_image varchar(255) null,
	UNIQUE (attribute_id, parent_id)
);
-- make sure www can use the table
GRANT ALL ON product.navigation_tree TO www;
GRANT ALL ON product.navigation_tree_id_seq TO www;


-- category navigation lock table
CREATE TABLE product.navigation_tree_lock (
	id serial primary key,
	navigation_tree_id integer not null references product.navigation_tree(id),
	operator_id integer null references operator(id),
	UNIQUE (navigation_tree_id, operator_id)
);
-- make sure www can use the table
GRANT ALL ON product.navigation_tree_lock TO www;
GRANT ALL ON product.navigation_tree_lock_id_seq TO www;


-- populate category tree

INSERT INTO product.navigation_tree (id, attribute_id, parent_id) VALUES (1, 1, null);

SELECT setval('product.navigation_tree_id_seq', (SELECT MAX(id) FROM product.navigation_tree));

INSERT INTO product.navigation_tree (attribute_id, parent_id) (SELECT id, 1 FROM product.attribute WHERE attribute_type_id = 1);

INSERT INTO product.navigation_tree (attribute_id, parent_id) (
SELECT cat.id, tr.id 
FROM product.attribute cat, product.attribute cat2, product_type pt, product p, classification c, product.navigation_tree tr  
WHERE cat.attribute_type_id = 2
AND cat.name = replace(pt.product_type, ' ', '_')
AND pt.id = p.product_type_id
AND p.id NOT IN (SELECT product_id FROM price_adjustment)
AND p.classification_id = c.id
AND c.classification = cat2.name
AND cat2.attribute_type_id = 1
AND cat2.id = tr.attribute_id
GROUP BY cat.id, tr.id
);


INSERT INTO product.navigation_tree (attribute_id, parent_id) (
SELECT cat.id, tr.id 
FROM product.attribute cat, product.attribute cat2, product.attribute cat3, sub_type st, product_type pt, product p, classification c, product.navigation_tree tr, product.navigation_tree tr2  
WHERE cat.attribute_type_id = 3
AND cat.name = replace(st.sub_type, ' ', '_')
AND st.id = p.sub_type_id

AND p.product_type_id = pt.id
AND replace(pt.product_type, ' ', '_') = cat2.name
AND cat2.attribute_type_id = 2
AND cat2.id = tr.attribute_id

AND tr.parent_id = tr2.id
AND tr2.attribute_id = cat3.id
AND cat3.name = c.classification
AND cat3.attribute_type_id = 1
AND p.classification_id = c.id

AND p.id NOT IN (SELECT product_id FROM price_adjustment)

GROUP BY cat.id, tr.id
);


-- Logging

-- log product attribute changes
CREATE TABLE product.log_attribute_value (
	id serial primary key,
	attribute_value_id integer not null references product.attribute_value(id),
	operator_id integer not null references operator(id),
	date timestamp NOT NULL default current_timestamp,
	action varchar(50) not null
);

-- make sure www can use the table
GRANT ALL ON product.log_attribute_value TO www;
GRANT ALL ON product.log_attribute_value_id_seq TO www;


-- log navigation tree changes
CREATE TABLE product.log_navigation_tree (
	id serial primary key,
	navigation_tree_id integer not null references product.navigation_tree(id),
	operator_id integer not null references operator(id),
	date timestamp NOT NULL default current_timestamp,
	action varchar(50) not null
);

-- make sure www can use the table
GRANT ALL ON product.log_navigation_tree TO www;
GRANT ALL ON product.log_navigation_tree_id_seq TO www;


COMMIT;
