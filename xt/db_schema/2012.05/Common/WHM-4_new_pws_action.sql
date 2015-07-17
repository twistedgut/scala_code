-- Add a new pws action for automatic stock resyncs

BEGIN;
    INSERT INTO pws_action ( action ) VALUES ( 'Auto-Resync PWS Inventory' );
COMMIT;
