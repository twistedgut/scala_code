-- Add a runtime property field for the printer digest

BEGIN;
    INSERT INTO runtime_property (name, value, description) VALUES
        ( 'printer_digest', '', 'A digest to store our existing printer list' )
    ;
COMMIT;
