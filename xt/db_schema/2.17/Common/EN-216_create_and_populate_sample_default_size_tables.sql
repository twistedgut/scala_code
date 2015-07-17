-- EN-216: Create & populate 'sample_product_type_default_size' & 'sample_classification_default_size'
--         tables to hold the ideal sample sizes for either product type or product classifications

BEGIN WORK;

CREATE TABLE sample_product_type_default_size (
    id SERIAL,
    product_type_id INTEGER REFERENCES product_type( id ) NOT NULL,
    size_id INTEGER REFERENCES size( id ) NOT NULL,
    channel_id INTEGER REFERENCES channel( id ) NOT NULL,
    CONSTRAINT sample_product_type_default_size_pkey PRIMARY KEY (id)
)
;
ALTER TABLE sample_product_type_default_size OWNER TO postgres;
GRANT ALL ON TABLE sample_product_type_default_size TO postgres;
GRANT ALL ON TABLE sample_product_type_default_size TO www;
GRANT ALL ON TABLE sample_product_type_default_size_id_seq TO postgres;
GRANT ALL ON TABLE sample_product_type_default_size_id_seq TO www;

CREATE TABLE sample_classification_default_size (
    id SERIAL,
    classification_id INTEGER REFERENCES classification( id ) NOT NULL,
    size_id INTEGER REFERENCES size( id ) NOT NULL,
    channel_id INTEGER REFERENCES channel( id ) NOT NULL,
    CONSTRAINT sample_classification_default_size_pkey PRIMARY KEY (id)
)
;
ALTER TABLE sample_classification_default_size OWNER TO postgres;
GRANT ALL ON TABLE sample_classification_default_size TO postgres;
GRANT ALL ON TABLE sample_classification_default_size TO www;
GRANT ALL ON TABLE sample_classification_default_size_id_seq TO postgres;
GRANT ALL ON TABLE sample_classification_default_size_id_seq TO www;

--
-- NAP
--

-- Populate 'sample_product_type_default_size'
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Lingerie'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP' )
    FROM    size
    WHERE   size IN ('34B','1')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Hats'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP' )
    FROM    size
    WHERE   size IN ('S/M')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Leggings'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP' )
    FROM    size
    WHERE   size IN ('L')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Ring'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP' )
    FROM    size
    WHERE   size IN ('P','medium','7','17')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Bracelet'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP' )
    FROM    size
    WHERE   size IN ('M')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Jeans'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP' )
    FROM    size
    WHERE   size IN ('27','28')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Belts'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP' )
    FROM    size
    WHERE   size IN ('small','75')
;
-- Populate 'sample_classification_default_size'
INSERT INTO sample_classification_default_size (classification_id, size_id, channel_id)
    SELECT  (SELECT id FROM classification WHERE classification = 'Clothing'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP' )
    FROM    size
    WHERE   size IN ('x small','small')
;
INSERT INTO sample_classification_default_size (classification_id, size_id, channel_id)
    SELECT  (SELECT id FROM classification WHERE classification = 'Shoes'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP' )
    FROM    size
    WHERE   size IN ('40','9.5')
;

--
-- OUTNET
--

-- Populate 'sample_product_type_default_size'
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Lingerie'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET' )
    FROM    size
    WHERE   size IN ('34C','1')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Hats'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET' )
    FROM    size
    WHERE   size IN ('S/M')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Leggings'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET' )
    FROM    size
    WHERE   size IN ('L')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Ring'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET' )
    FROM    size
    WHERE   size IN ('P','medium','7','17')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Bracelet'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET' )
    FROM    size
    WHERE   size IN ('M')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Jeans'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET' )
    FROM    size
    WHERE   size IN ('28')
;
INSERT INTO sample_product_type_default_size (product_type_id, size_id, channel_id)
    SELECT  (SELECT id FROM product_type WHERE product_type = 'Belts'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET' )
    FROM    size
    WHERE   size IN ('small','75')
;
-- Populate 'sample_classification_default_size'
INSERT INTO sample_classification_default_size (classification_id, size_id, channel_id)
    SELECT  (SELECT id FROM classification WHERE classification = 'Clothing'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET' )
    FROM    size
    WHERE   size IN ('small')
;
INSERT INTO sample_classification_default_size (classification_id, size_id, channel_id)
    SELECT  (SELECT id FROM classification WHERE classification = 'Shoes'),
            id,
            (SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET' )
    FROM    size
    WHERE   size IN ('40','9.5')
;

COMMIT WORK;
