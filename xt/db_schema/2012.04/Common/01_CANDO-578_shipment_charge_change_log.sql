-- CANDO-578: Create a new table 'shipment_shipping_charge_change_log'
--            to log the changes in charges that the script will do

BEGIN WORK;

CREATE TABLE shipment_shipping_charge_change_log (
    id                          SERIAL NOT NULL PRIMARY KEY,
    shipment_id                 INTEGER NOT NULL REFERENCES shipment(id),
    old_shipping_charge_id      INTEGER NOT NULL REFERENCES shipping_charge(id),
    old_shipping_account_id     INTEGER NOT NULL REFERENCES shipping_account(id),
    new_shipping_charge_id      INTEGER NOT NULL REFERENCES shipping_charge(id),
    new_shipping_account_id     INTEGER NOT NULL REFERENCES shipping_account(id),
    operator_id                 INTEGER NOT NULL REFERENCES operator(id),
    date                        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
)
;

ALTER TABLE shipment_shipping_charge_change_log OWNER TO postgres;
GRANT ALL ON TABLE shipment_shipping_charge_change_log TO postgres;
GRANT ALL ON TABLE shipment_shipping_charge_change_log TO www;

GRANT ALL ON SEQUENCE shipment_shipping_charge_change_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE shipment_shipping_charge_change_log_id_seq TO www;

COMMIT WORK;
