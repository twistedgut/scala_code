-- CANDO-1891: A new table to store the localised versions
--             of email addresses for different locales

BEGIN WORK;

CREATE TABLE localised_email_address (
    id                      SERIAL PRIMARY KEY,
    email_address           CHARACTER VARYING (255),
    locale                  CHARACTER VARYING (10),
    localised_email_address CHARACTER VARYING (255)
);
CREATE UNIQUE INDEX idx_localised_email_address__email_address__locale ON localised_email_address( LOWER(email_address::text), LOWER(locale::text) );
CREATE INDEX idx_localised_email_address__email_address ON localised_email_address( LOWER(email_address::text) );

ALTER TABLE localised_email_address OWNER TO postgres;
GRANT ALL ON TABLE localised_email_address TO postgres;
GRANT ALL ON TABLE localised_email_address TO www;

GRANT ALL ON SEQUENCE localised_email_address_id_seq TO postgres;
GRANT ALL ON SEQUENCE localised_email_address_id_seq TO www;

COMMIT WORK;
