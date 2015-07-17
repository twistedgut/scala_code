BEGIN;

CREATE TABLE product.storage_type (
    id SERIAL PRIMARY KEY,
    name TEXT,
    description TEXT,
    UNIQUE(name)
);

ALTER TABLE product.storage_type OWNER TO www;

INSERT INTO product.storage_type (name, description)
     VALUES ('Flat', 'Items that are stored flat'), 
            ('Hanging', 'Items that are stored hanging'), 
            ('Oversized', 'Items that fit in a tote, but sticks out or are stored in an "oversized" long tote'), 
            ('Awkward', 'Items that will not fit in any tote')
;

ALTER TABLE product
 ADD COLUMN storage_type_id INTEGER
 REFERENCES product.storage_type(id) 
 DEFERRABLE
;


COMMIT;