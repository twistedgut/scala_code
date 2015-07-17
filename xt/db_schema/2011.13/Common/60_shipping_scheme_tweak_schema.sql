BEGIN;

-- special tables for each carrier
CREATE TABLE shipping.nap (
    id INTEGER REFERENCES shipping.option(id) DEFERRABLE NOT NULL

);
ALTER TABLE shipping.nap OWNER TO www;

CREATE TABLE shipping.dhl (
    id INTEGER REFERENCES shipping.option(id) DEFERRABLE NOT NULL

);
ALTER TABLE shipping.dhl OWNER TO www;

CREATE TABLE shipping.ups (
    id INTEGER REFERENCES shipping.option(id) DEFERRABLE NOT NULL

);
ALTER TABLE shipping.ups OWNER TO www;



-- shipping.charge_class is being dropped
ALTER TABLE shipping.charge DROP COLUMN charge_class_id;

DROP TABLE shipping.charge_class;

ALTER TABLE shipping.account ADD COLUMN channel_id
    INTEGER REFERENCES public.channel(id) DEFERRABLE;


--account extension
ALTER TABLE shipping.account_type ADD COLUMN idx INTEGER;

ALTER TABLE shipping.option ADD COLUMN account_type_id
    INTEGER REFERENCES shipping.account_type(id) DEFERRABLE;

ALTER TABLE shipping.account DROP COLUMN option_id;



ALTER TABLE shipping.option DROP COLUMN code;
ALTER TABLE shipping.dhl ADD COLUMN code VARCHAR(255) NOT NULL;

COMMIT;
