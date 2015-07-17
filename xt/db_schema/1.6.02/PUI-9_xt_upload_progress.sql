/*****************************************************
* PUI-9: Upload process xT integration.
*
* Logging tables/views for upload transfer data,
* used to report upload transfer progress within xT 
*
*****************************************************/


DROP VIEW upload.vw_transfers;
DROP VIEW upload.vw_transfer_log;
DROP VIEW upload.vw_transfer_summary;

DROP TABLE upload.transfer_summary;
DROP TABLE upload.transfer_log;
DROP TABLE upload.transfer_log_action;
DROP TABLE upload.transfer;
DROP TABLE upload.transfer_status;


BEGIN;

/******************
* Tables
******************/

CREATE TABLE upload.transfer_status (
    id serial PRIMARY KEY,
    status varchar(50) NOT NULL,
    UNIQUE(status)
);
GRANT ALL ON upload.transfer_status TO www;
GRANT ALL ON upload.transfer_status_id_seq TO www;

INSERT INTO upload.transfer_status (id, status) VALUES (0, 'Unknown');
INSERT INTO upload.transfer_status (id, status) VALUES (1, 'In Progress');
INSERT INTO upload.transfer_status (id, status) VALUES (2, 'Completed Successfully');
INSERT INTO upload.transfer_status (id, status) VALUES (3, 'Completed with Errors');
SELECT setval('upload.transfer_status_id_seq', (SELECT max(id) FROM upload.transfer_status));



CREATE TABLE upload.transfer (
	id serial PRIMARY KEY,
    upload_id integer NOT NULL,
    operator_id integer NOT NULL REFERENCES operator(id),
    source varchar(20) NOT NULL,
    sink varchar(20) NOT NULL,
    environment varchar(20) NOT NULL,
    transfer_status_id integer NOT NULL DEFAULT 0 REFERENCES upload.transfer_status(id),
    dtm timestamp with time zone DEFAULT now()
);
CREATE INDEX ix_transfer__upload_id ON upload.transfer(upload_id);
CREATE INDEX ix_transfer__operator_id ON upload.transfer(operator_id);
CREATE INDEX ix_transfer__transfer_status_id ON upload.transfer(transfer_status_id);
GRANT ALL ON upload.transfer TO www;
GRANT ALL ON upload.transfer_id_seq TO www;



CREATE TABLE upload.transfer_log_action (
	id serial PRIMARY KEY,
	log_action varchar(50) NOT NULL,
	sequence integer NOT NULL,
	UNIQUE(log_action)
);
GRANT ALL ON upload.transfer_log_action TO www;
GRANT ALL ON upload.transfer_log_action_id_seq TO www;

INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (1, 'Product Data', 1);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (2, 'Product Attributes', 2);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (3, 'Product SKUs', 3);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (4, 'Product Pricing', 4);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (5, 'Product Inventory', 5);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (6, 'Product Reservations', 6);
INSERT INTO upload.transfer_log_action (id, log_action, sequence) VALUES (7, 'Related Products', 7);
SELECT setval('upload.transfer_log_action_id_seq', (SELECT max(id) FROM upload.transfer_log_action));



CREATE TABLE upload.transfer_log (
	id serial PRIMARY KEY,
    transfer_id integer NOT NULL REFERENCES upload.transfer(id),
    operator_id integer NOT NULL REFERENCES operator(id),
    product_id integer NOT NULL REFERENCES product(id),
    transfer_log_action_id integer NOT NULL REFERENCES upload.transfer_log_action(id),
	level varchar(20) NOT NULL,
	message text NOT NULL,
	dtm timestamp with time zone DEFAULT now(),
	UNIQUE(transfer_id, product_id, transfer_log_action_id)
);
CREATE INDEX ix_transfer_log__transfer_id ON upload.transfer_log(transfer_id);
CREATE INDEX ix_transfer_log__operator_id ON upload.transfer_log(operator_id);
CREATE INDEX ix_transfer_log__product_id ON upload.transfer_log(product_id);
CREATE INDEX ix_transfer_log__transfer_log_action_id ON upload.transfer_log(transfer_log_action_id);
GRANT ALL ON upload.transfer_log TO www;
GRANT ALL ON upload.transfer_log_id_seq TO www;



CREATE TABLE upload.transfer_summary (
    id serial PRIMARY KEY,
    transfer_id integer NOT NULL REFERENCES upload.transfer(id),
    category varchar(50) NOT NULL,
    num_pids_attempted integer,
    num_pids_succeeded integer,
    num_pids_failed integer
);
CREATE INDEX ix_transfer_summary__transfer_id ON upload.transfer_summary(transfer_id);
GRANT ALL ON upload.transfer_summary TO www;
GRANT ALL ON upload.transfer_summary_id_seq TO www;



/******************
* Views
******************/

CREATE OR REPLACE VIEW upload.vw_transfers AS
    SELECT
        t.*,
        to_char(t.dtm, 'DD-Mon-YYYY HH24:MI:SS') AS txt_dtm,
        tstat.status,
        u.upload_date,
        to_char(u.upload_date, 'DD-Mon-YYYY HH24:MI:SS') AS txt_upload_date,
        u.description,
        op.name AS operator_name,
        (SELECT count(product_id) FROM upload_product up WHERE up.upload_id = u.id) AS num_upload_products,
        (SELECT count(DISTINCT product_id) FROM upload.transfer_log tl WHERE tl.transfer_id = t.id) AS num_products_logged
    FROM upload.transfer t
    INNER JOIN upload.transfer_status tstat
        ON (t.transfer_status_id = tstat.id)
    INNER JOIN upload u
        ON (t.upload_id = u.id)
    INNER JOIN operator op
        ON (t.operator_id = op.id)
;
GRANT SELECT ON upload.vw_transfers TO www;



CREATE OR REPLACE VIEW upload.vw_transfer_log AS
    SELECT
        t.upload_id,
        t.transfer_status_id,
        tstat.status,
        tl.*,
        to_char(tl.dtm, 'DD-Mon-YYYY HH24:MI:SS') AS txt_dtm,
        tla.log_action,
        tla.sequence                
    FROM upload.transfer t
    INNER JOIN upload.transfer_status tstat
        ON (t.transfer_status_id = tstat.id)
    INNER JOIN upload.transfer_log tl
        ON (tl.transfer_id = t.id)
    INNER JOIN upload.transfer_log_action tla
        ON (tl.transfer_log_action_id = tla.id)
;
GRANT SELECT ON upload.vw_transfer_log TO www;



CREATE OR REPLACE VIEW upload.vw_transfer_summary AS
    SELECT
        t.upload_id,
        tsumm.*
    FROM upload.transfer t
    INNER JOIN upload.transfer_summary tsumm
        ON (tsumm.transfer_id = t.id)
;
GRANT SELECT ON upload.vw_transfer_summary TO www;


COMMIT;
