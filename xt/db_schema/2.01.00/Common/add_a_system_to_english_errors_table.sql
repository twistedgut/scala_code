-- Add a table called 'system_to_english_errors'
-- that translates between system messages and english
-- primarily used for the upload job workers

BEGIN WORK;

CREATE TABLE system_to_english_errors (
	id serial NOT NULL,
	module_name character varying(255) NOT NULL,
	system_error character varying(255) NOT NULL,
	english_translation text NOT NULL,
	CONSTRAINT system_to_english_errors_pkey PRIMARY KEY (id),
	CONSTRAINT system_to_english_errros_mod_sys UNIQUE (module_name,system_error)
);
ALTER TABLE system_to_english_errors OWNER TO postgres;
GRANT ALL ON TABLE system_to_english_errors TO postgres;
GRANT ALL ON TABLE system_to_english_errors TO www;

COMMIT WORK;

-- populate above table
BEGIN WORK;

INSERT INTO system_to_english_errors VALUES ( default, 'Receive::Upload::DoUpload', 'validation of ''name'' failed', 'Name Required' );
INSERT INTO system_to_english_errors VALUES ( default, 'Receive::Upload::DoUpload', 'validation of ''long_description'' failed', 'Long Description Required' );
INSERT INTO system_to_english_errors VALUES ( default, 'Receive::Upload::DoUpload', 'validation of ''hs_code'' failed', 'HS Code Required' );
INSERT INTO system_to_english_errors VALUES ( default, 'Receive::Upload::RelatedProducts', 'CONSTRAINT `FK_related_product_2`', 'A related product is not live' );

COMMIT WORK;
