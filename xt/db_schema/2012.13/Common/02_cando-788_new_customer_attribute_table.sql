-- CANDO-788

BEGIN;

CREATE TABLE customer_attribute (
    id                            SERIAL NOT NULL PRIMARY KEY,
    customer_id                   INTEGER NOT NULL UNIQUE REFERENCES customer(id),
    language_preference_id        INTEGER REFERENCES language(id)
);

ALTER TABLE customer_attribute OWNER             TO postgres;
GRANT ALL ON TABLE customer_attribute            TO postgres;
GRANT ALL ON TABLE customer_attribute            TO www;
GRANT ALL ON SEQUENCE customer_attribute_id_seq  TO postgres;
GRANT ALL ON SEQUENCE customer_attribute_id_seq  TO www;

CREATE INDEX customer_attribute_customer_idx ON customer_attribute(customer_id);
CREATE INDEX customer_attribute_language_preference_idx ON customer_attribute(language_preference_id);

COMMIT;
