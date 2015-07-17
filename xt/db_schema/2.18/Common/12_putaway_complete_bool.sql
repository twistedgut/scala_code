-- Complete should be a boolean
BEGIN;
    ALTER TABLE putaway ALTER complete DROP DEFAULT;
    ALTER TABLE putaway
        ALTER COLUMN complete TYPE bool
        USING
            CASE
                WHEN complete=1 THEN true
                ELSE false
            END
    ;
    ALTER TABLE putaway ALTER complete SET NOT NULL;
    ALTER TABLE putaway ALTER complete SET DEFAULT false;
COMMIT;
