-- Add an error message for the WhatsNew module

BEGIN WORK;

INSERT INTO system_to_english_errors VALUES ( default, 'Receive::Upload::WhatsNew', 'CONSTRAINT `FK_attribute_value_3`', 'A product has not been uploaded' );

COMMIT WORK;
