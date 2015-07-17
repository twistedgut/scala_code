-- CANDO-788

BEGIN;

CREATE TABLE language (
    id                          SERIAL NOT NULL PRIMARY KEY,
    code                        CHARACTER VARYING(5) NOT NULL UNIQUE,
    description                 CHARACTER VARYING(255) NOT NULL
);

CREATE INDEX language_code_idx ON language(code);

ALTER TABLE language OWNER             TO postgres;
GRANT ALL ON TABLE language            TO postgres;
GRANT ALL ON TABLE language            TO www;
GRANT ALL ON SEQUENCE language_id_seq  TO postgres;
GRANT ALL ON SEQUENCE language_id_seq  TO www;

INSERT INTO language(code, description) VALUES
('en', 'English'),
('fr', 'French'),
('de', 'German'),
('zh', 'Simplified Chinese');

COMMIT;
