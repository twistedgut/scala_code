BEGIN;


ALTER TABLE shipping.charge ADD COLUMN option_id INTEGER
    REFERENCES shipping.option(id) DEFERRABLE NOT NULL;

ALTER TABLE shipping.account DROP COLUMN account_type_id;

ALTER TABLE shipping.account_type RENAME TO option_type;

ALTER TABLE shipping.option RENAME  account_type_id TO option_type_id;


COMMIT;
