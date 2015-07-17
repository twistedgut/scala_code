BEGIN;

-- set carrier for premier account to 0 ('None') to prevent having to do left joins everywhere

INSERT INTO carrier VALUES (0, 'Unknown', '');
UPDATE shipping_account SET carrier_id = 0 WHERE id = 0;

-- now add a not null constraint on carrier id
ALTER TABLE shipping_account ALTER COLUMN carrier_id SET NOT NULL;

COMMIT;