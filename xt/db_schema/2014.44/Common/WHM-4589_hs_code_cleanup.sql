-- WHM-4589 Add a function to activate/disactivate given hs codes

BEGIN;

CREATE OR REPLACE FUNCTION activate_hs_codes(valid_hs_codes VARCHAR(255)[])
RETURNS VOID AS $$
DECLARE
    hs_code_row RECORD;

BEGIN
    IF array_length(valid_hs_codes,1) IS NULL THEN
        RAISE EXCEPTION 'valid_hs_codes cannot be empty';
    END IF;
    -- Loop through all of our hs codes
    FOR hs_code_row IN SELECT * FROM hs_code ORDER BY hs_code LOOP
        -- If our hs_code is in our valid list...
        IF hs_code_row.hs_code = ANY (valid_hs_codes) THEN
            -- If it's already active do nothing
            IF hs_code_row.active THEN
                RAISE NOTICE '%: already active', hs_code_row.hs_code;
                CONTINUE;
            END IF;
            -- If it's inactive, activate it
            RAISE NOTICE '%: making active', hs_code_row.hs_code;
            UPDATE hs_code SET active = true WHERE id = hs_code_row.id;
        -- If it's not it should be inactive...
        ELSE
            -- If it's already inactive do nothing
            IF NOT hs_code_row.active THEN
                RAISE NOTICE '%: already inactive', hs_code_row.hs_code;
                CONTINUE;
            END IF;
            -- If it's active, inactivate it
            RAISE NOTICE '%: inactivating', hs_code_row.hs_code;
            UPDATE hs_code SET active = false WHERE id = hs_code_row.id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION activate_hs_codes(VARCHAR(255)[]) IS
    'Make all HS codes in the array active and inactivate the rest. No HS codes are added if they don''t already exist.';

COMMIT;
