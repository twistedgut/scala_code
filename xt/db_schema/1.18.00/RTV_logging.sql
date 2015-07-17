/********************************
* RTV Enhancements: Logging
*
********************************/

BEGIN;

SELECT setval('stock_process_type_id_seq', (SELECT max(id) FROM stock_process_type));
INSERT INTO stock_process_type (type) VALUES ('RTV Customer Repair');
INSERT INTO stock_process_type (type) VALUES ('RTV Fixed');
INSERT INTO stock_process_type (type) VALUES ('Quarantine Fixed');
SELECT setval('stock_process_type_id_seq', (SELECT max(id) FROM stock_process_type));


/*****************
* rtv_action
*****************/
CREATE TABLE rtv_action (
    id serial PRIMARY KEY,
    action varchar(50) NOT NULL
);
GRANT ALL ON rtv_action TO www;
GRANT ALL ON rtv_action_id_seq TO www;

INSERT INTO rtv_action (action) VALUES ('Quarantined');
INSERT INTO rtv_action (action) VALUES ('Non-Faulty In');
INSERT INTO rtv_action (action) VALUES ('GI Faulty In');
INSERT INTO rtv_action (action) VALUES ('CR Dead');
INSERT INTO rtv_action (action) VALUES ('CR RTV');
INSERT INTO rtv_action (action) VALUES ('Manual Adjustment');
INSERT INTO rtv_action (action) VALUES ('RTV Shipment Pick');
INSERT INTO rtv_action (action) VALUES ('GI Faulty Fixed');
INSERT INTO rtv_action (action) VALUES ('Quarantine Fixed');


/*****************
* log_rtv_stock
*****************/
CREATE TABLE log_rtv_stock (
    id serial PRIMARY KEY,
    variant_id integer NOT NULL REFERENCES variant(id),
    rtv_action_id integer NOT NULL REFERENCES rtv_action(id),
    operator_id integer NOT NULL REFERENCES operator(id),
    notes text,
    quantity integer NOT NULL,
    balance integer NOT NULL,
    date timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP
);
CREATE INDEX ix_log_rtv_stock__operator_id ON log_rtv_stock(operator_id);
CREATE INDEX ix_log_rtv_stock__variant_id ON log_rtv_stock(variant_id);
GRANT ALL ON log_rtv_stock TO www;
GRANT ALL ON log_rtv_stock_id_seq TO www;

COMMIT;



--BEGIN;

/********************
* rtv_stock_process
********************/
/*
CREATE TABLE rtv_stock_process (
    stock_process_id integer PRIMARY KEY REFERENCES stock_process(id),
    
);
GRANT ALL ON rtv_stock_process TO www;
*/
--COMMIT;
