-- This patch will add credit hold threshold rules for MrP for both DCs
BEGIN;

CREATE OR REPLACE FUNCTION threshold_rules()
RETURNS VOID AS $$
DECLARE
    mrp_channel_id INTEGER;
    nap_channel_id INTEGER;
    threshold_name TEXT[];
    threshold_value INTEGER;

BEGIN
    -- Set the threshold names
    threshold_name[1] := 'Single Order Value';
    threshold_name[2] := 'Weekly Order Value';
    threshold_name[3] := 'Total Order Value';
    threshold_name[4] := 'Weekly Order Count';
    threshold_name[5] := 'Daily Order Count';

    -- Set the channel ids
    SELECT id INTO mrp_channel_id FROM channel WHERE business_id IN
        ( SELECT id FROM business WHERE name='MRPORTER.COM' )
    ;
    SELECT id INTO nap_channel_id FROM channel WHERE business_id IN
        ( SELECT id FROM business WHERE name='NET-A-PORTER.COM' )
    ;

    -- Set the sequence
    PERFORM setval('credit_hold_threshold_id_seq', (SELECT MAX(id) FROM credit_hold_threshold));

    -- Populate the table with MrP threshold rules
    FOR i in 1..array_upper(threshold_name, 1) LOOP
        SELECT value INTO threshold_value FROM credit_hold_threshold
            WHERE channel_id = nap_channel_id
              AND name = threshold_name[i]
        ;
        RAISE NOTICE 'Adding credit hold threshold rule for % against value of % on channel %',
            threshold_name[i], threshold_value, mrp_channel_id;

        INSERT INTO credit_hold_threshold ( channel_id, name, value ) VALUES
            ( mrp_channel_id, threshold_name[i], threshold_value )
        ;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT threshold_rules();
DROP FUNCTION threshold_rules();

COMMIT;
