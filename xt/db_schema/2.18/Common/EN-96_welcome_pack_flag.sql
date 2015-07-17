BEGIN;

-- ## Fix the Saucy Jason SQL bug
-- SELECT CURRVAL('promotion_type_id_seq');
SELECT MAX(id) FROM promotion_type;
SELECT SETVAL('promotion_type_id_seq', (SELECT MAX(id) FROM promotion_type));

-- # Add in the promotion types
INSERT INTO promotion_type (name, product_type, promotion_class_id) VALUES 
    ('Welcome Pack - French', 'french_welcome_pack', 2);
INSERT INTO promotion_type (name, product_type, promotion_class_id) VALUES 
    ('Welcome Pack - German', 'german_welcome_pack', 2);
INSERT INTO promotion_type (name, product_type, promotion_class_id) VALUES 
    ('Welcome Pack - Spanish', 'spanish_welcome_pack', 2);
INSERT INTO promotion_type (name, product_type, promotion_class_id) VALUES 
    ('Welcome Pack - Arabic', 'arabic_welcome_pack', 2);
INSERT INTO promotion_type (name, product_type, promotion_class_id) VALUES 
    ('Welcome Pack - English', 'english_welcome_pack', 2);

-- ## Now create a table mapping countries to welcome packs

CREATE TABLE country_promotion_type_welcome_pack (
    country_id          INTEGER PRIMARY KEY NOT NULL REFERENCES country(id),
    promotion_type_id   INTEGER NOT NULL REFERENCES promotion_type(id)
);

ALTER TABLE country_promotion_type_welcome_pack OWNER TO www;

-- ## Fill in the table

INSERT INTO country_promotion_type_welcome_pack 
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'FR'), 
        (SELECT id FROM promotion_type WHERE product_type = 'french_welcome_pack')
    );

INSERT INTO country_promotion_type_welcome_pack 
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'DE'), 
        (SELECT id FROM promotion_type WHERE product_type = 'german_welcome_pack')
    );


INSERT INTO country_promotion_type_welcome_pack 
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'ES'), 
        (SELECT id FROM promotion_type WHERE product_type = 'spanish_welcome_pack')
    );

INSERT INTO country_promotion_type_welcome_pack 
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'SA'), 
        (SELECT id FROM promotion_type WHERE product_type = 'arabic_welcome_pack')
    );

INSERT INTO country_promotion_type_welcome_pack 
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'AE'), 
        (SELECT id FROM promotion_type WHERE product_type = 'arabic_welcome_pack')
    );

INSERT INTO country_promotion_type_welcome_pack 
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'KW'), 
        (SELECT id FROM promotion_type WHERE product_type = 'arabic_welcome_pack')
    );

INSERT INTO country_promotion_type_welcome_pack 
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'QA'), 
        (SELECT id FROM promotion_type WHERE product_type = 'arabic_welcome_pack')
    );

INSERT INTO country_promotion_type_welcome_pack 
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'OM'), 
        (SELECT id FROM promotion_type WHERE product_type = 'arabic_welcome_pack')
    );

INSERT INTO country_promotion_type_welcome_pack 
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'BH'), 
        (SELECT id FROM promotion_type WHERE product_type = 'arabic_welcome_pack')
    );

INSERT INTO country_promotion_type_welcome_pack
    (country_id, promotion_type_id)
    VALUES (
        (SELECT id FROM country WHERE code = 'GB'),
        (SELECT id FROM promotion_type WHERE product_type = 'english_welcome_pack')
    );




COMMIT;
