BEGIN;

ALTER TABLE shipping.charge
    ALTER option_id DROP NOT NULL;

COMMIT;
