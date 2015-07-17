/*****************
* Drop DB Objects
*****************/
BEGIN;

DROP VIEW IF EXISTS vw_list_rma;
DROP VIEW IF EXISTS vw_rtv_quantity_check;
DROP VIEW IF EXISTS vw_rtv_shipment_details_with_results;
DROP VIEW IF EXISTS vw_rtv_shipment_detail_result_totals_row;
DROP VIEW IF EXISTS vw_rtv_shipment_detail_result_totals;
DROP VIEW IF EXISTS vw_rtv_inspection_validate_pick;
DROP VIEW IF EXISTS vw_rtv_inspection_list;
DROP VIEW IF EXISTS vw_rtv_inspection_pick_requested;
DROP VIEW IF EXISTS vw_rtv_inspection_pick_request_details;
DROP VIEW IF EXISTS vw_rtv_workstation_stock;
DROP VIEW IF EXISTS vw_rtv_inspection_stock;
DROP VIEW IF EXISTS vw_rtv_shipment_validate_pack;
DROP VIEW IF EXISTS vw_rtv_shipment_validate_pick;
DROP VIEW IF EXISTS vw_rtv_shipment_packlist;
DROP VIEW IF EXISTS vw_rtv_shipment_picklist;
DROP VIEW IF EXISTS vw_rtv_shipment_details;
DROP VIEW IF EXISTS vw_rma_request_designers;
DROP VIEW IF EXISTS vw_rma_request_notes;
DROP VIEW IF EXISTS vw_rma_request_details;
DROP VIEW IF EXISTS vw_designer_rtv_carrier;
DROP VIEW IF EXISTS vw_designer_rtv_address;
DROP VIEW IF EXISTS vw_rtv_address;
DROP VIEW IF EXISTS vw_rtv_stock_designers;
DROP VIEW IF EXISTS vw_rtv_stock_details;
DROP VIEW IF EXISTS vw_rtv_quantity;
DROP VIEW IF EXISTS vw_location_details;
DROP VIEW IF EXISTS vw_return_details;
DROP VIEW IF EXISTS vw_stock_order_details;
DROP VIEW IF EXISTS vw_delivery_details;
DROP VIEW IF EXISTS vw_stock_process;
DROP VIEW IF EXISTS vw_product_variant;


DROP TABLE IF EXISTS rtv_inspection_pick;
DROP TABLE IF EXISTS rtv_inspection_pick_request_detail;
DROP TABLE IF EXISTS rtv_inspection_pick_request;
DROP TABLE IF EXISTS rtv_inspection_pick_request_status;
DROP TABLE IF EXISTS rtv_shipment_pack;
DROP TABLE IF EXISTS rtv_shipment_pick;
DROP TABLE IF EXISTS rtv_shipment_detail_result;
DROP TABLE IF EXISTS rtv_shipment_detail_result_type;
DROP TABLE IF EXISTS rtv_shipment_packing_detail;
DROP TABLE IF EXISTS rtv_shipment_detail_status_log;
DROP TABLE IF EXISTS rtv_shipment_detail;
DROP TABLE IF EXISTS rtv_shipment_detail_status;
DROP TABLE IF EXISTS rtv_shipment_status_log;
DROP TABLE IF EXISTS rtv_shipment;
DROP TABLE IF EXISTS designer_rtv_carrier;
DROP TABLE IF EXISTS rtv_carrier;
DROP TABLE IF EXISTS designer_rtv_address;
DROP TABLE IF EXISTS rtv_address;
DROP TABLE IF EXISTS rtv_shipment_status;
DROP TABLE IF EXISTS rma_request_detail_status_log;
DROP TABLE IF EXISTS rma_request_detail;
DROP TABLE IF EXISTS rtv_quantity;
DROP TABLE IF EXISTS rma_request_detail_status;
DROP TABLE IF EXISTS rma_request_detail_type;
DROP TABLE IF EXISTS rma_request_note;
DROP TABLE IF EXISTS rma_request_status_log;
DROP TABLE IF EXISTS rma_request;
DROP TABLE IF EXISTS rma_request_status;
DROP TABLE IF EXISTS delivery_item_fault;
DROP TABLE IF EXISTS item_fault_type;

COMMIT;




/****************
* Alter Tables
****************/
BEGIN;
ALTER TABLE ONLY operator ADD COLUMN email_address varchar(255);
COMMIT;

BEGIN;
ALTER TABLE ONLY operator ADD COLUMN phone_ddi varchar(30);
COMMIT;


BEGIN;

/****************
* Create Tables
****************/

/*
* Name      : item_fault_type
* Descrip   : Lookup table of possible fault modes for a stock item
*/
DROP TABLE IF EXISTS item_fault_type;
CREATE TABLE item_fault_type (
	id serial PRIMARY KEY,
	fault_type varchar(50) NOT NULL,
	UNIQUE(fault_type)
);
GRANT ALL ON item_fault_type TO www;
GRANT ALL ON item_fault_type_id_seq TO www;

INSERT INTO item_fault_type (id, fault_type) VALUES (0, 'Unknown');
INSERT INTO item_fault_type (id, fault_type) VALUES (1, 'Various');
INSERT INTO item_fault_type (id, fault_type) VALUES (2, 'None');
INSERT INTO item_fault_type (id, fault_type) VALUES (3, 'Marked');
INSERT INTO item_fault_type (id, fault_type) VALUES (4, 'Stained');
INSERT INTO item_fault_type (id, fault_type) VALUES (5, 'Scuffed');
INSERT INTO item_fault_type (id, fault_type) VALUES (6, 'Torn/Ripped');
INSERT INTO item_fault_type (id, fault_type) VALUES (7, 'Missing Part');
SELECT setval('item_fault_type_id_seq', (SELECT max(id) FROM item_fault_type));



/*
* Name      : delivery_item_fault
* Descrip   : Delivery Item fault information
*/
CREATE TABLE delivery_item_fault (
    delivery_item_id integer REFERENCES delivery_item(id) PRIMARY KEY,
    fault_type_id integer REFERENCES item_fault_type(id),
	fault_description varchar(2000),
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP
);
CREATE INDEX ix_delivery_item_fault__fault_type_id ON delivery_item_fault(fault_type_id);
GRANT ALL ON delivery_item_fault TO www;



/*
* Name      : rma_request_status
* Descrip   : RMA request status
*/
CREATE TABLE rma_request_status (
    id serial PRIMARY KEY,
    status varchar(100) NOT NULL,
    UNIQUE(status)
);
GRANT ALL ON rma_request_status TO www;
GRANT ALL ON rma_request_status_id_seq TO www;

INSERT INTO rma_request_status (id, status) VALUES (0, 'Unknown');
INSERT INTO rma_request_status (id, status) VALUES (1, 'New');
INSERT INTO rma_request_status (id, status) VALUES (2, 'RMA Requested');
INSERT INTO rma_request_status (id, status) VALUES (3, 'RMA Received');
INSERT INTO rma_request_status (id, status) VALUES (4, 'RTV Processing');
INSERT INTO rma_request_status (id, status) VALUES (5, 'Complete');
SELECT setval('rma_request_status_id_seq', (SELECT max(id) FROM rma_request_status));



/*
* Name      : rma_request
* Descrip   : RMA request header
*/
CREATE TABLE rma_request (
    id serial PRIMARY KEY,
    operator_id integer NOT NULL REFERENCES operator(id),
    status_id integer NOT NULL REFERENCES rma_request_status(id),
    date_request timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP,
    date_complete timestamp without time zone,
    date_followup timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP + interval '10 days',
    rma_number varchar(50),
    comments varchar(2000)
);
CREATE INDEX ix_rma_request__operator_id ON rma_request(operator_id);
CREATE INDEX ix_rma_request__status_id ON rma_request(status_id);
GRANT ALL ON rma_request TO www;
GRANT ALL ON rma_request_id_seq TO www;



/*
* Name      : rma_request_status_log
* Descrip   : RMA request status log
*/
CREATE TABLE rma_request_status_log (
    id serial PRIMARY KEY,
    rma_request_id integer NOT NULL REFERENCES rma_request(id),
    rma_request_status_id integer NOT NULL REFERENCES rma_request_status(id),
    operator_id integer NOT NULL REFERENCES operator(id),
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP
);
CREATE INDEX ix_rma_request_status_log__rma_request_id ON rma_request_status_log(rma_request_id);
CREATE INDEX ix_rma_request_status_log__rma_request_status_id ON rma_request_status_log(rma_request_status_id);
CREATE INDEX ix_rma_request_status_log__operator_id ON rma_request_status_log(operator_id);
GRANT ALL ON rma_request_status_log TO www;
GRANT ALL ON rma_request_status_log_id_seq TO www;



/*
* Name      : rma_request_note
* Descrip   : Notes pertaining to a particular RMA request
*/
CREATE TABLE rma_request_note (
    id serial PRIMARY KEY,
    rma_request_id integer NOT NULL REFERENCES rma_request(id),
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP,
    operator_id integer NOT NULL REFERENCES operator(id),
    note text
);
CREATE INDEX rma_request_note__rma_request_id ON rma_request_note(rma_request_id);
CREATE INDEX rma_request_note__operator_id ON rma_request_note(operator_id);
GRANT ALL ON rma_request_note TO www;
GRANT ALL ON rma_request_note_id_seq TO www;



/*
* Name      : rma_request_detail_type
* Descrip   : 
*/
CREATE TABLE rma_request_detail_type (
    id serial PRIMARY KEY,
    type varchar(50) NOT NULL,
    UNIQUE(type)
);
GRANT ALL ON rma_request_detail_type TO www;
GRANT ALL ON rma_request_detail_type_id_seq TO www;

INSERT INTO rma_request_detail_type (id, type) VALUES (0, 'None');
INSERT INTO rma_request_detail_type (id, type) VALUES (1, 'Credit');
INSERT INTO rma_request_detail_type (id, type) VALUES (2, 'Customer Repair');
INSERT INTO rma_request_detail_type (id, type) VALUES (3, 'Replacement');
SELECT setval('rma_request_detail_type_id_seq', (SELECT max(id) FROM rma_request_detail_type));



/*
* Name      : rma_request_detail_status
* Descrip   : 
*/
CREATE TABLE rma_request_detail_status (
    id serial PRIMARY KEY,
    status varchar(50) NOT NULL,
    UNIQUE(status)
);
GRANT ALL ON rma_request_detail_status TO www;
GRANT ALL ON rma_request_detail_status_id_seq TO www;

INSERT INTO rma_request_detail_status (id, status) VALUES (0, 'Unknown');
INSERT INTO rma_request_detail_status (id, status) VALUES (1, 'New');
INSERT INTO rma_request_detail_status (id, status) VALUES (2, 'RTV');
INSERT INTO rma_request_detail_status (id, status) VALUES (3, 'Sent to Dead Stock');
INSERT INTO rma_request_detail_status (id, status) VALUES (4, 'Sent to Main Stock');
SELECT setval('rma_request_detail_status_id_seq', (SELECT max(id) FROM rma_request_detail_status));



/*
* Name      : rtv_quantity
* Descrip   : Details of RTV stock - quantity and fault information
*/
CREATE TABLE rtv_quantity (
	id serial PRIMARY KEY,
	variant_id integer NOT NULL REFERENCES variant(id),
	location_id integer NOT NULL REFERENCES location(id),
	quantity integer NOT NULL,
	delivery_item_id integer REFERENCES delivery_item(id),
	fault_type_id integer NOT NULL DEFAULT 0 REFERENCES item_fault_type(id),
	fault_description varchar(2000),
	origin varchar(20) NOT NULL,
	date_created timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP
);
CREATE INDEX ix_rtv_quantity__variant_id ON rtv_quantity(variant_id);
CREATE INDEX ix_rtv_quantity__location_id ON rtv_quantity(location_id);
CREATE INDEX ix_rtv_quantity__delivery_item_id ON rtv_quantity(delivery_item_id);
CREATE INDEX ix_rtv_quantity__fault_type_id ON rtv_quantity(fault_type_id);
CREATE INDEX ix_rtv_quantity__origin ON rtv_quantity(origin);
GRANT ALL ON rtv_quantity TO www;
GRANT ALL ON rtv_quantity_id_seq TO www;



/*
* Name      : rtv_quantity_log
* Descrip   : 
*/
/*
CREATE TABLE rtv_quantity_log (
	id serial PRIMARY KEY,
	variant_id integer NOT NULL REFERENCES variant(id),
	location_id integer NOT NULL REFERENCES location(id),
	quantity integer NOT NULL,
	delivery_item_id integer REFERENCES delivery_item(id),
	fault_type_id integer NOT NULL DEFAULT 0 REFERENCES item_fault_type(id),
	fault_description varchar(2000),
	origin varchar(20) NOT NULL,
	operator_id integer NOT NULL REFERENCES operator(id),
	date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP 
);
CREATE INDEX ix_rtv_quantity_log__variant_id ON rtv_quantity_log(variant_id);
CREATE INDEX ix_rtv_quantity_log__location_id ON rtv_quantity_log(location_id);
CREATE INDEX ix_rtv_quantity_log__delivery_item_id ON rtv_quantity_log(delivery_item_id);
CREATE INDEX ix_rtv_quantity_log__fault_type_id ON rtv_quantity_log(fault_type_id);
CREATE INDEX ix_rtv_quantity_log__origin ON rtv_quantity_log(origin);
GRANT ALL ON rtv_quantity_log TO www;
GRANT ALL ON rtv_quantity_log_id_seq TO www;
*/


/*
* Name      : rma_request_detail
* Descrip   : RMA request detail
*/
CREATE TABLE rma_request_detail (
    id serial  PRIMARY KEY,
    rma_request_id integer NOT NULL REFERENCES rma_request(id),
	rtv_quantity_id integer NOT NULL,
    delivery_item_id integer REFERENCES delivery_item(id),
    variant_id integer NOT NULL REFERENCES variant(id),
    quantity integer NOT NULL,
    fault_type_id integer REFERENCES item_fault_type(id),
	fault_description varchar(2000),
    type_id integer NOT NULL REFERENCES rma_request_detail_type(id) DEFAULT 0,
    status_id integer NOT NULL REFERENCES rma_request_detail_status(id)
);
CREATE INDEX ix_rma_request_detail__rma_request_id ON rma_request_detail(rma_request_id);
CREATE INDEX ix_rma_request_detail__rtv_quantity_id ON rma_request_detail(rtv_quantity_id);
CREATE INDEX ix_rma_request_detail__delivery_item_id ON rma_request_detail(delivery_item_id);
CREATE INDEX ix_rma_request_detail__variant_id ON rma_request_detail(variant_id);
CREATE INDEX ix_rma_request_detail__fault_type_id ON rma_request_detail(fault_type_id);
CREATE INDEX ix_rma_request_detail__type_id ON rma_request_detail(type_id);
CREATE INDEX ix_rma_request_detail__status_id ON rma_request_detail(status_id);
GRANT ALL ON rma_request_detail TO www;
GRANT ALL ON rma_request_detail_id_seq TO www;



/*
* Name      : rma_request_detail_status_log
* Descrip   : RMA request detail status log
*/
CREATE TABLE rma_request_detail_status_log (
    id serial PRIMARY KEY,
    rma_request_detail_id integer NOT NULL REFERENCES rma_request_detail(id),
    rma_request_detail_status_id integer NOT NULL REFERENCES rma_request_detail_status(id),
    operator_id integer NOT NULL REFERENCES operator(id),
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP
);
CREATE INDEX ix_rma_request_detail_status_log__rma_request_detail_id ON rma_request_detail_status_log(rma_request_detail_id);
CREATE INDEX ix_rma_request_detail_status_log__rma_request_detail_status_id ON rma_request_detail_status_log(rma_request_detail_status_id);
CREATE INDEX ix_rma_request_detail_status_log__operator_id ON rma_request_detail_status_log(operator_id);
GRANT ALL ON rma_request_detail_status_log TO www;
GRANT ALL ON rma_request_detail_status_log_id_seq TO www;



/*
* Name      : rtv_shipment_status
* Descrip   : RTV shipment status lookup 
*/
CREATE TABLE rtv_shipment_status (
	id serial PRIMARY KEY,
	status varchar(100) NOT NULL,
	UNIQUE(status)
);
GRANT ALL ON rtv_shipment_status TO www;
GRANT ALL ON rtv_shipment_status_id_seq TO www;

INSERT INTO rtv_shipment_status (id, status) VALUES (0, 'Unknown');
INSERT INTO rtv_shipment_status (id, status) VALUES (1, 'New');
INSERT INTO rtv_shipment_status (id, status) VALUES (2, 'Picking');
INSERT INTO rtv_shipment_status (id, status) VALUES (3, 'Picked');
INSERT INTO rtv_shipment_status (id, status) VALUES (4, 'Packing');
INSERT INTO rtv_shipment_status (id, status) VALUES (5, 'Awaiting Dispatch');
INSERT INTO rtv_shipment_status (id, status) VALUES (6, 'Hold');
INSERT INTO rtv_shipment_status (id, status) VALUES (7, 'Dispatched');
INSERT INTO rtv_shipment_status (id, status) VALUES (8, 'Lost');
SELECT setval('rtv_shipment_status_id_seq', (SELECT max(id) FROM rtv_shipment_status));



/*
* Name      : rtv_address
* Descrip   : delivery addresses for RTV shipments
*/
CREATE TABLE rtv_address (
    id serial PRIMARY KEY,
    address_line_1 varchar(255) NOT NULL,
    address_line_2 varchar(255) NOT NULL,
    address_line_3 varchar(255) NOT NULL,
    town_city varchar(255) NOT NULL,
    region_county varchar(255) NOT NULL,
    postcode_zip varchar(50) NOT NULL,
    country varchar(255) NOT NULL
);
GRANT ALL ON rtv_address TO www;
GRANT ALL ON rtv_address_id_seq TO www;



/*
* Name      : designer_rtv_address
* Descrip   : link entity - designer to rtv_address
*/
CREATE TABLE designer_rtv_address (
    id serial PRIMARY KEY,
    designer_id integer NOT NULL REFERENCES designer(id),
    rtv_address_id integer NOT NULL REFERENCES rtv_address(id),
    contact_name varchar(200) NOT NULL,
    do_not_use boolean,
    UNIQUE(designer_id, rtv_address_id, contact_name)
);
CREATE INDEX ix_designer_rtv_address__designer_id ON designer_rtv_address(designer_id);
CREATE INDEX ix_designer_rtv_address__rtv_address_id ON designer_rtv_address(rtv_address_id);
GRANT ALL ON designer_rtv_address TO www;
GRANT ALL ON designer_rtv_address_id_seq TO www;



/*
* Name      : rtv_carrier
* Descrip   : RTV carrier details
*/
CREATE TABLE rtv_carrier (
    id serial PRIMARY KEY,
    name varchar(255) NOT NULL,
    UNIQUE(name)
);
GRANT ALL ON rtv_carrier TO www;
GRANT ALL ON rtv_carrier_id_seq TO www;

INSERT INTO rtv_carrier (id, name) VALUES (1, 'Vendor Collection');
INSERT INTO rtv_carrier (id, name) VALUES (2, 'DHL');
INSERT INTO rtv_carrier (id, name) VALUES (3, 'FedEx');
INSERT INTO rtv_carrier (id, name) VALUES (4, 'Parcel Force');
INSERT INTO rtv_carrier (id, name) VALUES (5, 'UPS');
SELECT setval('rtv_carrier_id_seq', (SELECT max(id) FROM rtv_carrier));



/*
* Name      : designer_rtv_carrier
* Descrip   : link entity - designer to rtv_carrier
*/
CREATE TABLE designer_rtv_carrier (
    id serial PRIMARY KEY,
    designer_id integer NOT NULL REFERENCES designer(id),
    rtv_carrier_id integer NOT NULL REFERENCES rtv_carrier(id),
    account_ref varchar(100) NOT NULL,
    do_not_use boolean,
    UNIQUE(designer_id, rtv_carrier_id, account_ref)
);
CREATE INDEX ix_designer_rtv_carrier__designer_id ON designer_rtv_carrier(designer_id);
CREATE INDEX ix_designer_rtv_carrier__rtv_carrier_id ON designer_rtv_carrier(rtv_carrier_id);
GRANT ALL ON designer_rtv_carrier TO www;
GRANT ALL ON designer_rtv_carrier_id_seq TO www;



/*
* Name      : rtv_shipment
* Descrip   : RTV shipment
*/
CREATE TABLE rtv_shipment (
    id serial PRIMARY KEY,
	designer_rtv_carrier_id integer NOT NULL REFERENCES designer_rtv_carrier(id),
	designer_rtv_address_id integer NOT NULL REFERENCES designer_rtv_address(id),
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP,
    status_id integer NOT NULL REFERENCES rtv_shipment_status(id),
    airway_bill varchar(40)
);
CREATE INDEX ix_rtv_shipment__designer_rtv_carrier_id ON rtv_shipment(designer_rtv_carrier_id);
CREATE INDEX ix_rtv_shipment__designer_rtv_address_id ON rtv_shipment(designer_rtv_address_id);
CREATE INDEX ix_rtv_shipment__status_id ON rtv_shipment(status_id);
GRANT ALL ON rtv_shipment TO www;
GRANT ALL ON rtv_shipment_id_seq TO www;



/*
* Name      : rtv_shipment_status_log
* Descrip   : RTV shipment status log
*/
CREATE TABLE rtv_shipment_status_log (
    id serial PRIMARY KEY,
    rtv_shipment_id integer NOT NULL REFERENCES rtv_shipment(id),
    rtv_shipment_status_id integer NOT NULL REFERENCES rtv_shipment_status(id),
    operator_id integer NOT NULL REFERENCES operator(id),
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP
);
CREATE INDEX ix_rtv_shipment_status_log__rtv_shipment_id ON rtv_shipment_status_log(rtv_shipment_id);
CREATE INDEX ix_rtv_shipment_status_log__rtv_shipment_status_id ON rtv_shipment_status_log(rtv_shipment_status_id);
CREATE INDEX ix_rtv_shipment_status_log__operator_id ON rtv_shipment_status_log(operator_id);
GRANT ALL ON rtv_shipment_status_log TO www;
GRANT ALL ON rtv_shipment_status_log_id_seq TO www;



/*
* Name      : rtv_shipment_detail_status
* Descrip   : RTV shipment detail status lookup 
*/
CREATE TABLE rtv_shipment_detail_status (
	id serial PRIMARY KEY,
	status varchar(100) NOT NULL,
	UNIQUE(status)
);
GRANT ALL ON rtv_shipment_detail_status TO www;
GRANT ALL ON rtv_shipment_detail_status_id_seq TO www;

INSERT INTO rtv_shipment_detail_status (id, status) VALUES (0, 'Unknown');
INSERT INTO rtv_shipment_detail_status (id, status) VALUES (1, 'New');
INSERT INTO rtv_shipment_detail_status (id, status) VALUES (2, 'Picking');
INSERT INTO rtv_shipment_detail_status (id, status) VALUES (3, 'Picked');
INSERT INTO rtv_shipment_detail_status (id, status) VALUES (4, 'Packing');
INSERT INTO rtv_shipment_detail_status (id, status) VALUES (5, 'Awaiting Dispatch');
INSERT INTO rtv_shipment_detail_status (id, status) VALUES (6, 'Dispatched');
SELECT setval('rtv_shipment_detail_status_id_seq', (SELECT max(id) FROM rtv_shipment_detail_status));



/*
* Name      : rtv_shipment_detail
* Descrip   : RTV shipment detail
*/
CREATE TABLE rtv_shipment_detail (
    id serial PRIMARY KEY,
    rtv_shipment_id integer NOT NULL REFERENCES rtv_shipment(id),
    rma_request_detail_id integer NOT NULL REFERENCES rma_request_detail(id),
    quantity integer NOT NULL,
    status_id integer NOT NULL REFERENCES rtv_shipment_detail_status(id)
);
CREATE INDEX ix_rtv_shipment_detail__rtv_shipment_id ON rtv_shipment_detail(rtv_shipment_id);
CREATE INDEX ix_rtv_shipment_detail__rma_request_detail_id ON rtv_shipment_detail(rma_request_detail_id);
CREATE INDEX ix_rtv_shipment_detail__status_id ON rtv_shipment_detail(status_id);
GRANT ALL ON rtv_shipment_detail TO www;
GRANT ALL ON rtv_shipment_detail_id_seq TO www;



/*
* Name      : rtv_shipment_detail_status_log
* Descrip   : RTV shipment detail status log
*/
CREATE TABLE rtv_shipment_detail_status_log (
    id serial PRIMARY KEY,
    rtv_shipment_detail_id integer NOT NULL REFERENCES rtv_shipment_detail(id),
    rtv_shipment_detail_status_id integer NOT NULL REFERENCES rtv_shipment_detail_status(id),
    operator_id integer NOT NULL REFERENCES operator(id),
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP
);
CREATE INDEX ix_rtv_shipment_detail_status_log__rtv_shipment_detail_id ON rtv_shipment_detail_status_log(rtv_shipment_detail_id);
CREATE INDEX ix_rtv_shipment_detail_status_log__rtv_shipment_detail_status_id ON rtv_shipment_detail_status_log(rtv_shipment_detail_status_id);
CREATE INDEX ix_rtv_shipment_detail_status_log__operator_id ON rtv_shipment_detail_status_log(operator_id);
GRANT ALL ON rtv_shipment_detail_status_log TO www;
GRANT ALL ON rtv_shipment_detail_status_log_id_seq TO www;



/*
* Name      : rtv_shipment_packing_detail
* Descrip   : 
*/
CREATE TABLE rtv_shipment_packing_detail (
    id serial PRIMARY KEY,
    rtv_shipment_id integer NOT NULL REFERENCES rtv_shipment(id),
    rtv_shipment_detail_id integer NOT NULL REFERENCES rtv_shipment_detail(id),
    quantity integer NOT NULL,
    box_id integer NOT NULL REFERENCES box(id),
    operator_id integer NOT NULL REFERENCES operator(id),
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP
);
CREATE INDEX ix_rtv_shipment_packing_detail__rtv_shipment_id ON rtv_shipment_packing_detail(rtv_shipment_id);
CREATE INDEX ix_rtv_shipment_packing_detail__rtv_shipment_detail_id ON rtv_shipment_packing_detail(rtv_shipment_detail_id);
CREATE INDEX ix_rtv_shipment_packing_detail__box_id ON rtv_shipment_packing_detail(box_id);
CREATE INDEX ix_rtv_shipment_packing_detail__operator_id ON rtv_shipment_packing_detail(operator_id);
GRANT ALL ON rtv_shipment_packing_detail TO www;
GRANT ALL ON rtv_shipment_packing_detail_id_seq TO www;



/*
* Name      : rtv_shipment_detail_result_type
* Descrip   : 
*/
CREATE TABLE rtv_shipment_detail_result_type (
    id serial PRIMARY KEY,
    type varchar(50) NOT NULL,
    UNIQUE(type)
);
GRANT ALL ON rtv_shipment_detail_result_type TO www;
GRANT ALL ON rtv_shipment_detail_result_type_id_seq TO www;

INSERT INTO rtv_shipment_detail_result_type (id, type) VALUES (0, 'Unknown');
INSERT INTO rtv_shipment_detail_result_type (id, type) VALUES (1, 'Credited');
INSERT INTO rtv_shipment_detail_result_type (id, type) VALUES (2, 'Repaired');
INSERT INTO rtv_shipment_detail_result_type (id, type) VALUES (3, 'Replaced');
INSERT INTO rtv_shipment_detail_result_type (id, type) VALUES (4, 'Dead');
SELECT setval('rtv_shipment_detail_result_type_id_seq', (SELECT max(id) FROM rtv_shipment_detail_result_type));



/*
* Name      : rtv_shipment_detail_result
* Descrip   : 
*/
CREATE TABLE rtv_shipment_detail_result (
    id serial PRIMARY KEY,
    operator_id integer NOT NULL REFERENCES operator(id),
    rtv_shipment_detail_id integer NOT NULL REFERENCES rtv_shipment_detail(id),
    type_id integer NOT NULL REFERENCES rtv_shipment_detail_result_type(id),
    quantity integer NOT NULL,
    reference varchar(100),
    notes varchar(2000),
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP    
);
CREATE INDEX ix_rtv_shipment_detail_result__operator_id ON rtv_shipment_detail_result(operator_id);
CREATE INDEX ix_rtv_shipment_detail_result__rtv_shipment_detail_id ON rtv_shipment_detail_result(rtv_shipment_detail_id);
CREATE INDEX ix_rtv_shipment_detail_result__type_id ON rtv_shipment_detail_result(type_id);
GRANT ALL ON rtv_shipment_detail_result TO www;
GRANT ALL ON rtv_shipment_detail_result_id_seq TO www;



/*
* Name      : rtv_shipment_pick
* Descrip   : picking details, used for validation
*/
CREATE TABLE rtv_shipment_pick (
    id serial PRIMARY KEY,
    operator_id integer NOT NULL REFERENCES operator(id),    
    rtv_shipment_id integer NOT NULL REFERENCES rtv_shipment(id),
    location varchar(255),
    sku varchar(10) NOT NULL,
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP,
    cancelled timestamp without time zone
);
CREATE INDEX ix_rtv_shipment_pick__operator_id ON rtv_shipment_pick(operator_id);
CREATE INDEX ix_rtv_shipment_pick__rtv_shipment_id ON rtv_shipment_pick(rtv_shipment_id);
CREATE INDEX ix_rtv_shipment_pick__location ON rtv_shipment_pick(location);
CREATE INDEX ix_rtv_shipment_pick__sku ON rtv_shipment_pick(sku);
GRANT ALL ON rtv_shipment_pick TO www;
GRANT ALL ON rtv_shipment_pick_id_seq TO www;



/*
* Name      : rtv_shipment_pack
* Descrip   : packing details, used for validation
*/
CREATE TABLE rtv_shipment_pack (
    id serial PRIMARY KEY,
    operator_id integer NOT NULL REFERENCES operator(id),    
    rtv_shipment_id integer NOT NULL REFERENCES rtv_shipment(id),
    sku varchar(10) NOT NULL,
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP,
    cancelled timestamp without time zone
);
CREATE INDEX ix_rtv_shipment_pack__operator_id ON rtv_shipment_pack(operator_id);
CREATE INDEX ix_rtv_shipment_pack__rtv_shipment_id ON rtv_shipment_pack(rtv_shipment_id);
CREATE INDEX ix_rtv_shipment_pack__sku ON rtv_shipment_pack(sku);
GRANT ALL ON rtv_shipment_pack TO www;
GRANT ALL ON rtv_shipment_pack_id_seq TO www;



/*
* Name      : rtv_inspection_pick_request_status
* Descrip   : 
*/
CREATE TABLE rtv_inspection_pick_request_status (
    id serial PRIMARY KEY,
    status varchar(100) NOT NULL,
    UNIQUE(status)
);

INSERT INTO rtv_inspection_pick_request_status (id, status) VALUES (0, 'Unknown');
INSERT INTO rtv_inspection_pick_request_status (id, status) VALUES (1, 'New');
INSERT INTO rtv_inspection_pick_request_status (id, status) VALUES (2, 'Picking');
INSERT INTO rtv_inspection_pick_request_status (id, status) VALUES (3, 'Picked');
SELECT setval('rtv_inspection_pick_request_status_id_seq', (SELECT max(id) FROM rtv_inspection_pick_request_status));
GRANT ALL ON rtv_inspection_pick_request_status TO www;
GRANT ALL ON rtv_inspection_pick_request_status_id_seq TO www;



/*
* Name      : rtv_inspection_pick_request
* Descrip   : 
*/
CREATE TABLE rtv_inspection_pick_request (
    id serial PRIMARY KEY,
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP,
    status_id integer NOT NULL REFERENCES rtv_inspection_pick_request_status(id) DEFAULT 0,
    operator_id integer NOT NULL REFERENCES operator(id)
);
CREATE INDEX ix_rtv_inspection_pick_request__status_id ON rtv_inspection_pick_request(status_id);
CREATE INDEX ix_rtv_inspection_pick_request__operator_id ON rtv_inspection_pick_request(operator_id);
GRANT ALL ON rtv_inspection_pick_request TO www;
GRANT ALL ON rtv_inspection_pick_request_id_seq TO www;



/*
* Name      : rtv_inspection_pick_request_detail
* Descrip   : 
*/
CREATE TABLE rtv_inspection_pick_request_detail (
    id serial PRIMARY KEY,
    rtv_inspection_pick_request_id integer NOT NULL REFERENCES rtv_inspection_pick_request(id),
    rtv_quantity_id integer NOT NULL --REFERENCES rtv_quantity(id)
);
CREATE INDEX ix_rtv_inspection_pick_request_detail__rtv_inspection_pick_request_id ON rtv_inspection_pick_request_detail(rtv_inspection_pick_request_id);
CREATE INDEX ix_rtv_inspection_pick_request_detail__rtv_quantity_id ON rtv_inspection_pick_request_detail(rtv_quantity_id);
GRANT ALL ON rtv_inspection_pick_request_detail TO www;
GRANT ALL ON rtv_inspection_pick_request_detail_id_seq TO www;



/*
* Name      : rtv_inspection_pick
* Descrip   : inspection picking details, used for validation
*/
CREATE TABLE rtv_inspection_pick (
    id serial PRIMARY KEY,
    operator_id integer NOT NULL REFERENCES operator(id),    
    rtv_inspection_pick_request_id integer NOT NULL REFERENCES rtv_inspection_pick_request(id),
    location varchar(255),
    sku varchar(10) NOT NULL,
    date_time timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP,
    cancelled timestamp without time zone
);
CREATE INDEX ix_rtv_inspection_pick__operator_id ON rtv_inspection_pick(operator_id);
CREATE INDEX ix_rtv_inspection_pick__rtv_inspection_pick_request_id ON rtv_inspection_pick(rtv_inspection_pick_request_id);
CREATE INDEX ix_rtv_inspection_pick__location ON rtv_inspection_pick(location);
CREATE INDEX ix_rtv_inspection_pick__sku ON rtv_inspection_pick(sku);
GRANT ALL ON rtv_inspection_pick TO www;
GRANT ALL ON rtv_inspection_pick_id_seq TO www;





/****************
* Create Views
****************/

/*
* Name      : vw_product_variant
* Descrip   : Product and variant details.
*/
CREATE OR REPLACE VIEW vw_product_variant AS
    SELECT
        v.product_id,
        p.world_id,
        w.world,
        p.classification_id,
        c.classification,
        p.product_type_id,
        pt.product_type,
        p.designer_id,
        d.designer,
        p.colour_id,
        col.colour,
        pa.designer_colour_code,
        pa.designer_colour,
        p.style_number,
        p.season_id,
        s.season,
        pa.name,
        pa.description,
        p.visible,
        p.live,
        p.staging,
        v.id AS variant_id,
        v.product_id || '-' || lpad(CAST(v.size_id AS varchar), 3, '0') AS sku,
        v.legacy_sku,
        v.type_id AS variant_type_id,
        vt.type AS variant_type,
        v.size_id,
        sz.size,
        nsz.nap_size,
        v.designer_size_id,
        dsz.size AS designer_size
    FROM product p
    INNER JOIN product_attribute pa
        ON (p.id = pa.product_id)
    INNER JOIN designer d
        ON (p.designer_id = d.id) 
    INNER JOIN colour col
        ON (p.colour_id = col.id) 
    INNER JOIN world w
        ON (p.world_id = w.id)
    INNER JOIN classification c
        ON (p.classification_id = c.id) 
    INNER JOIN product_type pt
        ON (p.product_type_id = pt.id) 
    INNER JOIN season s
        ON (p.season_id = s.id)
    INNER JOIN variant v
        ON (p.id = v.product_id)
    INNER JOIN variant_type vt
        ON (v.type_id = vt.id)
    LEFT JOIN size sz
        ON (v.size_id = sz.id)
    LEFT JOIN nap_size nsz
        ON (v.nap_size_id = nsz.id)
    LEFT JOIN size dsz
        ON (v.designer_size_id = dsz.id)
;
GRANT SELECT ON vw_product_variant TO www;



/*
* Name      : vw_stock_process
* Descrip   : Stock process details and statuses.
*/
CREATE VIEW vw_stock_process AS
    SELECT
        sp.id AS stock_process_id,
        sp.delivery_item_id,
        sp.quantity,
        sp.group_id,
        sp.type_id AS stock_process_type_id,
        spt.type AS stock_process_type,
        sp.status_id AS stock_process_status_id,
        sps.status AS stock_process_status,
        sp.complete
    FROM stock_process sp
    INNER JOIN stock_process_type spt
        ON (sp.type_id = spt.id)
    INNER JOIN stock_process_status sps
        ON (sp.status_id = sps.id)
;
GRANT SELECT ON vw_stock_process TO www;



/*
* Name      : vw_delivery_details
* Descrip   : Delivery and delivery item details and statuses.
*/
CREATE VIEW vw_delivery_details AS
    SELECT
        d.id AS delivery_id,
        d.date,
        d.invoice_nr,
        d.cancel AS delivery_cancel,
        d.type_id AS delivery_type_id,
        dt.type AS delivery_type,
        d.status_id AS delivery_status_id,
        ds.status AS delivery_status,
        di.id AS delivery_item_id,
        di.packing_slip,
        di.quantity,
        di.cancel AS delivery_item_cancel,
        di.type_id AS delivery_item_type_id,
        dit.type AS delivery_item_type,
        di.status_id AS delivery_item_status_id,
        dis.status AS delivery_item_status
    FROM delivery d
    INNER JOIN delivery_type dt
        ON (d.type_id = dt.id)
    INNER JOIN delivery_status ds
        ON (d.status_id = ds.id)
    INNER JOIN delivery_item di
        ON (di.delivery_id = d.id)
    INNER JOIN delivery_item_type dit
        ON (di.type_id = dit.id)
    INNER JOIN delivery_item_status dis
        ON (di.status_id = dis.id)
;
GRANT SELECT ON vw_delivery_details TO www;



/*
* Name      : vw_stock_order_details
* Descrip   : Stock order and stock order item details and statuses.
*/
CREATE VIEW vw_stock_order_details AS
    SELECT
        so.id AS stock_order_id,
        so.product_id,
        so.purchase_order_id,
        so.start_ship_date,
        so.cancel_ship_date,
        so.status_id AS stock_order_status_id,
        sos.status AS stock_order_status,
        so.comment,
        so.type_id AS stock_order_type_id,
        sot.type AS stock_order_type,
        so.consignment,
        so.cancel AS stock_order_cancel,
        soi.id AS stock_order_item_id,
        soi.variant_id,
        soi.quantity,
        soi.status_id AS stock_order_item_status_id,
        sois.status AS stock_order_item_status,
        soi.status_id AS stock_order_item_type_id,
        soit.type AS stock_order_item_type,
        soi.cancel AS stock_order_item_cancel,
        soi.original_quantity
    FROM stock_order so
    INNER JOIN stock_order_type sot
        ON (so.type_id = sot.id)
    INNER JOIN stock_order_status sos
        ON (so.status_id = sos.id)
    INNER JOIN stock_order_item soi
        ON (soi.stock_order_id = so.id)
    INNER JOIN stock_order_item_type soit
        ON (soi.type_id = soit.id)
    INNER JOIN stock_order_item_status sois
        ON (soi.status_id = sois.id)
;
GRANT SELECT ON vw_stock_order_details TO www;



/*
* Name      : vw_return_details
* Descrip   : Return and return item details and statuses.
*/
CREATE VIEW vw_return_details AS
    SELECT
        r.id AS return_id,
        r.shipment_id,
        r.rma_number,
        r.return_status_id,
        rs.status AS return_status,
        r.comment,
        r.exchange_shipment_id,
        r.pickup,
        ri.id AS return_item_id,
        ri.shipment_item_id,
        ri.return_item_status_id,
        ris.status AS return_item_status,
        cit.description AS customer_issue_type_description,
        ri.return_type_id AS return_item_type_id,
        rt.type AS return_item_type,
        ri.return_airway_bill,
        ri.variant_id
    FROM return r
    INNER JOIN return_status rs
        ON (r.return_status_id = rs.id)
    INNER JOIN return_item ri
        ON (ri.return_id = r.id)
    INNER JOIN return_type rt
        ON (ri.return_type_id = rt.id)
    INNER JOIN return_item_status ris
        ON (ri.return_item_status_id = ris.id)
    INNER JOIN customer_issue_type cit
        ON (ri.customer_issue_type_id = cit.id)
;
GRANT SELECT ON vw_return_details TO www;



/*
* Name      : vw_location_details
* Descrip   : 
*/
CREATE OR REPLACE VIEW vw_location_details AS
	SELECT
		l.id AS location_id,
		l.location,
	    SUBSTRING(location, E'\\A(\\d{2})\\d[a-zA-Z]-?\\d{3,4}[a-zA-Z]\\Z') AS loc_dc,
        SUBSTRING(location, E'\\A\\d{2}(\\d)[a-zA-Z]-?\\d{3,4}[a-zA-Z]\\Z') AS loc_floor,
        SUBSTRING(location, E'\\A\\d{2}\\d([a-zA-Z])-?\\d{3,4}[a-zA-Z]\\Z') AS loc_zone,
        SUBSTRING(location, E'\\A\\d{2}\\d[a-zA-Z]-?(\\d{3,4})[a-zA-Z]\\Z') AS loc_section,
        SUBSTRING(location, E'\\A\\d{2}\\d[a-zA-Z]-?\\d{3,4}([a-zA-Z])\\Z') AS loc_shelf,
		lt.id AS location_type_id,
		lt.type AS location_type
	FROM location l
	INNER JOIN location_type lt
		ON (l.type_id = lt.id)	
;
GRANT SELECT ON vw_location_details TO www;




/*
* Name      : vw_rtv_quantity 
* Descrip   : 
*/
CREATE VIEW vw_rtv_quantity AS
    SELECT
        rq.*,
        v.product_id,
        l.location,
        lt.type AS location_type,
        rrd.rma_request_id,    
        rrd.id AS rma_request_detail_id,
        rrd.quantity AS rma_request_detail_quantity,
        rsd.rtv_shipment_id,
        rsd.id AS rtv_shipment_detail_id,
        rsd.quantity AS rtv_shipment_detail_quantity
    FROM rtv_quantity rq
    INNER JOIN location l
        ON (rq.location_id = l.id)
    INNER JOIN location_type lt
        ON (l.type_id = lt.id)
    INNER JOIN variant v
        ON rq.variant_id = v.id
    LEFT JOIN rma_request_detail rrd
        ON (rrd.rtv_quantity_id = rq.id)
    LEFT JOIN rtv_shipment_detail rsd
        ON (rsd.rma_request_detail_id = rrd.id)
;
GRANT SELECT ON vw_rtv_quantity TO www;



/*
* Name      : vw_rtv_stock_details 
* Descrip   : 
*/
CREATE VIEW vw_rtv_stock_details AS
	SELECT
		rq.id AS rtv_quantity_id,
		rq.variant_id,
		rq.location_id,
		rq.origin,
		rq.date_created AS rtv_quantity_date,
		vw_ld.location,
		vw_ld.loc_dc,
		vw_ld.loc_floor,
		vw_ld.loc_zone,
		vw_ld.loc_section,
		vw_ld.loc_shelf,
        vw_ld.location_type,
		rq.quantity,
		rq.fault_type_id,
		ft.fault_type,
		rq.fault_description,
		vw_dd.delivery_id,
		vw_dd.delivery_item_id,
        vw_dd.delivery_item_type,
        vw_dd.delivery_item_status,
        vw_dd.date AS delivery_date,
        to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI') AS txt_delivery_date,
        vw_pv.product_id,
        vw_pv.size_id,
        vw_pv.size,
        vw_pv.designer_size_id,
        vw_pv.designer_size,
        vw_pv.sku,
        vw_pv.name,
        vw_pv.description,
        vw_pv.designer_id,
        vw_pv.designer,
        vw_pv.style_number,
        vw_pv.colour,
        vw_pv.designer_colour_code,
        vw_pv.designer_colour,
        vw_pv.product_type_id,
        vw_pv.product_type,
        vw_pv.classification_id,
        vw_pv.classification,
        vw_pv.season_id,
        vw_pv.season,
        rrd.rma_request_id        
	FROM rtv_quantity rq
	INNER JOIN vw_location_details vw_ld
		ON (rq.location_id = vw_ld.location_id)
	INNER JOIN vw_product_variant vw_pv
		ON (rq.variant_id = vw_pv.variant_id)
    LEFT JOIN item_fault_type ft
	    ON (rq.fault_type_id = ft.id)		
    LEFT JOIN rma_request_detail rrd
		ON (rq.id = rrd.rtv_quantity_id)
	LEFT JOIN vw_delivery_details vw_dd
		ON (rq.delivery_item_id = vw_dd.delivery_item_id)
;
GRANT SELECT ON vw_rtv_stock_details TO www;



/*
* Name      : vw_rtv_stock_designers 
* Descrip   : list distinct designers for RTV stock items
*/
CREATE VIEW vw_rtv_stock_designers AS
    SELECT DISTINCT designer_id, designer
    FROM rtv_quantity rq
    INNER JOIN variant v
        ON (rq.variant_id = v.id)
    INNER JOIN product p
        ON (v.product_id = p.id)    
    INNER JOIN designer d
        ON p.designer_id = d.id
;
GRANT SELECT ON vw_rtv_stock_designers TO www;



/*
* Name      : vw_rtv_address
* Descrip   : rtv_address details, with MD5 hash (hex)
*/
CREATE VIEW vw_rtv_address AS
    SELECT
        *,
        md5(
            btrim( lower(address_line_1) )
            || btrim( lower(address_line_2) )
            || btrim( lower(address_line_3) )
            || btrim( lower(country) )
            || btrim( lower(postcode_zip) )            
            || btrim( lower(region_county) )
            || btrim( lower(town_city) )
        ) AS address_hash
    FROM rtv_address
;
GRANT SELECT ON vw_rtv_address TO www;



/*
* Name      : vw_designer_rtv_address
* Descrip   : 
*/
CREATE VIEW vw_designer_rtv_address AS
    SELECT
        d.id AS designer_id,
        d.designer,
        vw_ra.id AS rtv_address_id,
        vw_ra.address_line_1,
        vw_ra.address_line_2,
        vw_ra.address_line_3,
        vw_ra.town_city,
        vw_ra.region_county,
        vw_ra.postcode_zip,
        vw_ra.country,
        vw_ra.address_hash,
        d_ra.id AS designer_rtv_address_id,
        d_ra.contact_name,
        d_ra.do_not_use
    FROM designer d
    INNER JOIN designer_rtv_address d_ra
        ON (d.id = d_ra.designer_id)
    INNER JOIN vw_rtv_address vw_ra
        ON (vw_ra.id = d_ra.rtv_address_id)
;
GRANT SELECT ON vw_designer_rtv_address TO www;



/*
* Name      : vw_designer_rtv_carrier
* Descrip   : 
*/
CREATE VIEW vw_designer_rtv_carrier AS
    SELECT
        d.id AS designer_id,
        d.designer,
        rc.id AS rtv_carrier_id,
        rc.name AS rtv_carrier_name,
        d_rc.id AS designer_rtv_carrier_id,
        d_rc.account_ref,
        CASE coalesce(d_rc.account_ref, '') WHEN '' THEN rc.name ELSE rc.name || ' : ' || d_rc.account_ref END AS designer_carrier, 
        d_rc.do_not_use
    FROM designer d
    INNER JOIN designer_rtv_carrier d_rc
        ON (d.id = d_rc.designer_id)
    RIGHT JOIN rtv_carrier rc
        ON (rc.id = d_rc.rtv_carrier_id)
;
GRANT SELECT ON vw_designer_rtv_carrier TO www;


/*
* Name      : vw_rma_request_details 
* Descrip   : 
*/
CREATE VIEW vw_rma_request_details AS
    SELECT
        rr.id AS rma_request_id,
        rr.operator_id,
        op.name AS operator_name,
        op.email_address,
        rr.status_id AS rma_request_status_id,
        rrs.status AS rma_request_status,
        rr.date_request,
        to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI') AS txt_date_request,
        rr.date_followup,
        to_char(rr.date_followup, 'DD-Mon-YYYY') AS txt_date_followup,
        rr.rma_number,
        rr.comments AS rma_request_comments,
        rrd.id AS rma_request_detail_id,
        rrd.rtv_quantity_id,
        vw_pv.product_id,
        vw_pv.size_id,
        vw_pv.sku,
        vw_pv.variant_id,
        vw_pv.designer_id,
        vw_pv.designer,
        vw_pv.season_id,
        vw_pv.season,
        vw_pv.style_number,
        vw_pv.colour,
        vw_pv.designer_colour_code,
        vw_pv.designer_colour,
        vw_pv.name,
        vw_pv.description,
        vw_pv.size,
        vw_pv.designer_size,
        vw_pv.nap_size,
        vw_pv.product_type,
        vw_dd.delivery_item_id,
        vw_dd.delivery_item_type,
        vw_dd.date AS delivery_date,
        to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI') AS txt_delivery_date,
		rrd.quantity AS rma_request_detail_quantity,
		ift.fault_type,
		rrd.fault_description,
        rrdt.id AS rma_request_detail_type_id,
        rrdt.type AS rma_request_detail_type,
        rrds.id AS rma_request_detail_status_id,
        rrds.status AS rma_request_detail_status,
        vw_rstkd.quantity AS rtv_stock_detail_quantity,
        vw_rstkd.location,
        vw_rstkd.loc_dc,
        vw_rstkd.loc_floor,
        vw_rstkd.loc_zone,
        vw_rstkd.loc_section,
        vw_rstkd.loc_shelf,
        vw_rstkd.location_type
    FROM rma_request rr
    INNER JOIN rma_request_status rrs
        ON (rr.status_id = rrs.id)
    INNER JOIN operator op
        ON (rr.operator_id = op.id)
    INNER JOIN rma_request_detail rrd
        ON (rrd.rma_request_id = rr.id)
    INNER JOIN rma_request_detail_type rrdt
        ON (rrd.type_id = rrdt.id)
    INNER JOIN item_fault_type ift
        ON (rrd.fault_type_id = ift.id)
    INNER JOIN rma_request_detail_status rrds
        ON (rrd.status_id = rrds.id)
    LEFT JOIN vw_rtv_stock_details vw_rstkd
        ON (rrd.rtv_quantity_id = vw_rstkd.rtv_quantity_id)
    INNER JOIN vw_product_variant vw_pv
        ON (rrd.variant_id = vw_pv.variant_id)
	LEFT JOIN vw_delivery_details vw_dd
        ON (rrd.delivery_item_id = vw_dd.delivery_item_id)
;
GRANT SELECT ON vw_rma_request_details TO www;



/*
* Name      : vw_rma_request_notes 
* Descrip   : 
*/
CREATE VIEW vw_rma_request_notes AS
    SELECT
        rrn.id AS rma_request_note_id,
        rrn.rma_request_id,
        rrn.date_time,
        to_char(rrn.date_time, 'DD-Mon-YYYY HH24:MI') AS txt_date_time,
        rrn.note,
        rrn.operator_id,
        o.name AS operator_name,
        o.department_id,
        o.email_address,
        d.department
    FROM rma_request_note rrn
    INNER JOIN operator o
        ON (rrn.operator_id = o.id)
    LEFT JOIN department d
        ON (o.department_id = d.id)
;
GRANT SELECT ON vw_rma_request_notes TO www;



/*
* Name      : vw_rma_request_designers 
* Descrip   : list distinct designers for all items which have appeared on RMA requests
*/
CREATE VIEW vw_rma_request_designers AS
    SELECT DISTINCT designer_id, designer
    FROM rma_request_detail rrd
    INNER JOIN variant v
        ON (rrd.variant_id = v.id)
    INNER JOIN product p
        ON (v.product_id = p.id)    
    INNER JOIN designer d
        ON p.designer_id = d.id
;
GRANT SELECT ON vw_rma_request_designers TO www;



/*
* Name      : vw_rtv_shipment_details 
* Descrip   : 
*/
CREATE VIEW vw_rtv_shipment_details AS
    SELECT
        rs.id AS rtv_shipment_id,
        rs.designer_rtv_carrier_id,
        vw_drc.rtv_carrier_name,
        vw_drc.account_ref AS carrier_account_ref,
        rs.designer_rtv_address_id,
        vw_dra.contact_name,
        vw_dra.address_line_1,
        vw_dra.address_line_2,
        vw_dra.address_line_3,
        vw_dra.town_city,
        vw_dra.region_county,
        vw_dra.postcode_zip,
        vw_dra.country,
        rs.date_time AS rtv_shipment_date,
        to_char(rs.date_time, 'DD-Mon-YYYY HH24:MI') AS txt_rtv_shipment_date,
        rs.status_id AS rtv_shipment_status_id,
        rss.status AS rtv_shipment_status,
        rs.airway_bill,
        vw_rrd.*,
        rsd.id AS rtv_shipment_detail_id,
        rsd.quantity AS rtv_shipment_detail_quantity,
        rsd.status_id AS rtv_shipment_detail_status_id,
        rsds.status AS rtv_shipment_detail_status
    FROM rtv_shipment rs
    INNER JOIN rtv_shipment_status rss
        ON (rs.status_id = rss.id)
    INNER JOIN rtv_shipment_detail rsd
        ON (rsd.rtv_shipment_id = rs.id)
    INNER JOIN rtv_shipment_detail_status rsds
        ON (rsd.status_id = rsds.id)
    INNER JOIN vw_designer_rtv_carrier vw_drc
        ON(rs.designer_rtv_carrier_id = vw_drc.designer_rtv_carrier_id)
    INNER JOIN vw_designer_rtv_address vw_dra
        ON (rs.designer_rtv_address_id = vw_dra.designer_rtv_address_id)
    INNER JOIN vw_rma_request_details vw_rrd
        ON (rsd.rma_request_detail_id = vw_rrd.rma_request_detail_id)
;
GRANT SELECT ON vw_rtv_shipment_details TO www;



/*
* Name      : vw_rtv_shipment_picklist
* Descrip   : 
*/
CREATE VIEW vw_rtv_shipment_picklist AS
    SELECT
        rs.id AS rtv_shipment_id,
        rs.status_id AS rtv_shipment_status_id,
        rss.status AS rtv_shipment_status,
        rs.date_time AS rtv_shipment_date,
        to_char(rs.date_time, 'DD-Mon-YYYY HH24:MI') AS txt_rtv_shipment_date,
        rsd.status_id AS rtv_shipment_detail_status_id,
        rsds.status AS rtv_shipment_detail_status,
        rsd.quantity AS rtv_shipment_detail_quantity,
        rr.id AS rma_request_id,
        rr.status_id AS rma_request_status_id,
        rr.date_request,
        to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI') AS txt_date_request,
        rrd.status_id AS rma_request_detail_status_id,
        rrd.fault_description,
        vw_pv.designer,
        vw_pv.sku,
        vw_pv.name,
        vw_pv.description,
        vw_pv.designer_size,
        vw_pv.colour,
        ift.fault_type,
        vw_ld.location,
        vw_ld.loc_dc,
        vw_ld.loc_floor,
        vw_ld.loc_zone,
        vw_ld.loc_section,
        vw_ld.loc_shelf,
        vw_ld.location_type
    FROM rtv_shipment rs
    INNER JOIN rtv_shipment_status rss
        ON (rs.status_id = rss.id)
    INNER JOIN rtv_shipment_detail rsd
        ON (rsd.rtv_shipment_id = rs.id)
    INNER JOIN rtv_shipment_detail_status rsds
        ON (rsd.status_id = rsds.id)
    INNER JOIN rma_request_detail rrd
        ON (rrd.id = rsd.rma_request_detail_id)
    INNER JOIN vw_product_variant vw_pv
        ON (rrd.variant_id = vw_pv.variant_id)
    INNER JOIN item_fault_type ift
        ON (rrd.fault_type_id = ift.id)
    INNER JOIN rtv_quantity rq
        ON (rrd.rtv_quantity_id = rq.id)
    INNER JOIN vw_location_details vw_ld
        ON (rq.location_id = vw_ld.location_id)
    INNER JOIN rma_request rr
        ON (rrd.rma_request_id = rr.id)
;
GRANT SELECT ON vw_rtv_shipment_picklist TO www;



/*
* Name      : vw_rtv_shipment_packlist
* Descrip   : 
*/
CREATE VIEW vw_rtv_shipment_packlist AS
    SELECT
        rs.id AS rtv_shipment_id,
        rs.status_id AS rtv_shipment_status_id,
        rss.status AS rtv_shipment_status,
        rs.date_time AS rtv_shipment_date,
        to_char(rs.date_time, 'DD-Mon-YYYY HH24:MI') AS txt_rtv_shipment_date,
        rsd.status_id AS rtv_shipment_detail_status_id,
        rsds.status AS rtv_shipment_detail_status,
        rsd.quantity AS rtv_shipment_detail_quantity,
        rr.id AS rma_request_id,
        rr.status_id AS rma_request_status_id,
        rr.date_request,
        to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI') AS txt_date_request,
        rrd.status_id AS rma_request_detail_status_id,
        rrd.fault_description,
        vw_pv.designer,
        vw_pv.sku,
        vw_pv.name,
        vw_pv.description,
        vw_pv.designer_size,
        vw_pv.colour,
        ift.fault_type
    FROM rtv_shipment rs
    INNER JOIN rtv_shipment_status rss
        ON (rs.status_id = rss.id)
    INNER JOIN rtv_shipment_detail rsd
        ON (rsd.rtv_shipment_id = rs.id)
    INNER JOIN rtv_shipment_detail_status rsds
        ON (rsd.status_id = rsds.id)
    INNER JOIN rma_request_detail rrd
        ON (rrd.id = rsd.rma_request_detail_id)
    INNER JOIN vw_product_variant vw_pv
        ON (rrd.variant_id = vw_pv.variant_id)
    INNER JOIN item_fault_type ift
        ON (rrd.fault_type_id = ift.id)
    INNER JOIN rma_request rr
        ON (rrd.rma_request_id = rr.id)
;
GRANT SELECT ON vw_rtv_shipment_packlist TO www;



/*
* Name      : vw_rtv_shipment_validate_pick
* Descrip   : 
*/
CREATE VIEW vw_rtv_shipment_validate_pick AS 
    SELECT
        A.rtv_shipment_id, A.rtv_shipment_status_id, A.rtv_shipment_status,
        A.location, A.loc_dc, A.loc_floor, A.loc_zone, A.loc_section, A.loc_shelf, A.location_type, 
        A.sku,
        A.sum_picklist_quantity, coalesce(B.picked_quantity, 0) AS picked_quantity,
        (A.sum_picklist_quantity - coalesce(B.picked_quantity, 0)) AS remaining_to_pick
    FROM
        (SELECT rtv_shipment_id, rtv_shipment_status_id, rtv_shipment_status, location, loc_dc, loc_floor, loc_zone, loc_section, loc_shelf, location_type,
            sku, sum(rtv_shipment_detail_quantity) AS sum_picklist_quantity
        FROM vw_rtv_shipment_picklist
        WHERE rtv_shipment_status IN ('New', 'Picking')
        GROUP BY rtv_shipment_id, rtv_shipment_status_id, rtv_shipment_status, sku, location, loc_dc, loc_floor, loc_zone, loc_section, loc_shelf, location_type) A
    LEFT JOIN
        (SELECT rtv_shipment_id, location, sku, count(*) AS picked_quantity
        FROM rtv_shipment_pick
        WHERE cancelled IS NULL
        GROUP BY rtv_shipment_id, sku, location) B
        ON (A.sku = B.sku AND A.location = B.location AND A.rtv_shipment_id = B.rtv_shipment_id)
;
GRANT SELECT ON vw_rtv_shipment_validate_pick TO www;



/*
* Name      : vw_rtv_shipment_validate_pack
* Descrip   : 
*/
CREATE VIEW vw_rtv_shipment_validate_pack AS 
    SELECT
        A.rtv_shipment_id, A.rtv_shipment_status_id, A.rtv_shipment_status, A.sku,
        A.sum_packlist_quantity, coalesce(B.packed_quantity, 0) AS packed_quantity,
        (A.sum_packlist_quantity - coalesce(B.packed_quantity, 0)) AS remaining_to_pack
    FROM
        (SELECT rtv_shipment_id, rtv_shipment_status_id, rtv_shipment_status,
            sku, sum(rtv_shipment_detail_quantity) AS sum_packlist_quantity
        FROM vw_rtv_shipment_packlist
        WHERE rtv_shipment_status IN ('Picked', 'Packing')
        GROUP BY rtv_shipment_id, rtv_shipment_status_id, rtv_shipment_status, sku) A
    LEFT JOIN
        (SELECT rtv_shipment_id, sku, count(*) AS packed_quantity
        FROM rtv_shipment_pack
        WHERE cancelled IS NULL
        GROUP BY rtv_shipment_id, sku) B
        ON (A.sku = B.sku AND A.rtv_shipment_id = B.rtv_shipment_id)
;
GRANT SELECT ON vw_rtv_shipment_validate_pack TO www;



/*
* Name      : vw_rtv_inspection_stock
* Descrip   : RTV stock in locations of type 'RTV Goods In' grouped by product_id, origin, delivery_id
*/
CREATE VIEW vw_rtv_inspection_stock AS
    SELECT
        product_id,
        origin,
        max(vw_rtv_stock_details.rtv_quantity_date) AS rtv_quantity_date,
        to_char(max(vw_rtv_stock_details.rtv_quantity_date), 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date,
        designer_id,
        designer,
        colour,
        product_type,
        delivery_id,
        delivery_date,
        txt_delivery_date,
        sum(quantity) AS sum_quantity    
    FROM vw_rtv_stock_details
    WHERE location_type = 'RTV Goods In'
    GROUP BY product_id, origin, designer_id, designer, colour, product_type, delivery_id, delivery_date, txt_delivery_date
;
GRANT SELECT ON vw_rtv_inspection_stock TO www;



/*
* Name      : vw_rtv_workstation_stock
* Descrip   : RTV stock in locations of type 'RTV Workstation' grouped by location, product_id, delivery_id
*/
CREATE VIEW vw_rtv_workstation_stock AS
    SELECT
        location_id,
        location,
        product_id,
        origin,
        max(vw_rtv_stock_details.rtv_quantity_date) AS rtv_quantity_date,
        to_char(max(vw_rtv_stock_details.rtv_quantity_date), 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date,
        designer_id,
        designer,
        colour,
        product_type,
        delivery_id,
        delivery_date,
        txt_delivery_date,
        sum(quantity) AS sum_quantity
    FROM vw_rtv_stock_details
    WHERE location_type = 'RTV Workstation'
    GROUP BY location_id, location, product_id, origin, designer_id, designer, colour, product_type, delivery_id, delivery_date, txt_delivery_date
;
GRANT SELECT ON vw_rtv_workstation_stock TO www;



/*
* Name      : vw_rtv_inspection_pick_request_details
* Descrip   : 
*/
CREATE VIEW vw_rtv_inspection_pick_request_details AS
    SELECT
        ripr.id AS rtv_inspection_pick_request_id,
        ripr.date_time,
        to_char(ripr.date_time, 'DD-Mon-YYYY HH24:MI') AS txt_date_time,
        riprd.id AS rtv_inspection_pick_request_item_id,
        riprd.rtv_quantity_id,
        ripr.status_id,
        riprs.status,
        vw_rstkd.product_id,
        vw_rstkd.origin,
        vw_rstkd.sku,
        vw_rstkd.designer,        
        vw_rstkd.name,
        vw_rstkd.colour,
        vw_rstkd.designer_size,
        vw_rstkd.variant_id,
        vw_rstkd.delivery_id,
        vw_rstkd.delivery_item_id,
        vw_rstkd.quantity,
        vw_rstkd.fault_type,
        vw_rstkd.fault_description,
        vw_rstkd.location,
        vw_rstkd.loc_dc,
        vw_rstkd.loc_floor,
        vw_rstkd.loc_zone,
        vw_rstkd.loc_section,
        vw_rstkd.loc_shelf,
        vw_rstkd.location_type
    FROM rtv_inspection_pick_request ripr
    INNER JOIN rtv_inspection_pick_request_status riprs
        ON (ripr.status_id = riprs.id)
    INNER JOIN rtv_inspection_pick_request_detail riprd
        ON (riprd.rtv_inspection_pick_request_id = ripr.id)
    INNER JOIN vw_rtv_stock_details vw_rstkd
        ON (riprd.rtv_quantity_id = vw_rstkd.rtv_quantity_id)  
;
GRANT SELECT ON vw_rtv_inspection_pick_request_details TO www;



/*
* Name      : vw_rtv_inspection_pick_requested
* Descrip   : 
*/
CREATE VIEW vw_rtv_inspection_pick_requested AS
    SELECT 
        product_id,
        origin,
        delivery_id,
        sum(quantity) AS quantity_requested
    FROM vw_rtv_inspection_pick_request_details
    WHERE status IN ('New', 'Picking')
    GROUP BY product_id, origin, delivery_id
;
GRANT ALL ON vw_rtv_inspection_pick_requested TO www;



/*
* Name      : vw_rtv_inspection_list
* Descrip   : 
*/
CREATE VIEW vw_rtv_inspection_list AS
    SELECT
        vw_ris.product_id,
        vw_ris.origin,
        vw_ris.rtv_quantity_date,
        vw_ris.txt_rtv_quantity_date,
        vw_ris.designer_id,
        vw_ris.designer,
        vw_ris.colour,
        vw_ris.product_type,
        vw_ris.delivery_id,
        vw_ris.delivery_date,
        vw_ris.txt_delivery_date,
        vw_ris.sum_quantity,
        coalesce(vw_ripr.quantity_requested, 0) AS quantity_requested,
        vw_ris.sum_quantity - coalesce(vw_ripr.quantity_requested, 0) AS quantity_remaining    
    FROM vw_rtv_inspection_stock vw_ris
    LEFT JOIN vw_rtv_inspection_pick_requested vw_ripr
        ON (vw_ris.product_id = vw_ripr.product_id AND vw_ris.origin = vw_ripr.origin AND vw_ris.delivery_id = vw_ripr.delivery_id)
;
GRANT SELECT ON vw_rtv_inspection_list TO www;



/*
* Name      : vw_rtv_inspection_validate_pick
* Descrip   : 
*/
CREATE VIEW vw_rtv_inspection_validate_pick AS 
    SELECT
        A.rtv_inspection_pick_request_id, A.status_id, A.status,
        A.location, A.loc_dc, A.loc_floor, A.loc_zone, A.loc_section, A.loc_shelf, A.location_type, 
        A.sku,
        A.sum_picklist_quantity, coalesce(B.picked_quantity, 0) AS picked_quantity,
        (A.sum_picklist_quantity - coalesce(B.picked_quantity, 0)) AS remaining_to_pick
    FROM
        (SELECT rtv_inspection_pick_request_id, status_id, status, location, loc_dc, loc_floor, loc_zone, loc_section, loc_shelf, location_type,
            sku, sum(quantity) AS sum_picklist_quantity
        FROM vw_rtv_inspection_pick_request_details
        WHERE status IN ('New', 'Picking')
        GROUP BY rtv_inspection_pick_request_id, status_id, status, sku, location, loc_dc, loc_floor, loc_zone, loc_section, loc_shelf, location_type) A
    LEFT JOIN
        (SELECT rtv_inspection_pick_request_id, location, sku, count(*) AS picked_quantity
        FROM rtv_inspection_pick
        WHERE cancelled IS NULL
        GROUP BY rtv_inspection_pick_request_id, sku, location) B
        ON (A.sku = B.sku AND A.location = B.location AND A.rtv_inspection_pick_request_id = B.rtv_inspection_pick_request_id)
;
GRANT SELECT ON vw_rtv_inspection_validate_pick TO www;



/*
* Name      : vw_rtv_shipment_detail_result_totals
* Descrip   : Shipment detail result totals summed for each result_type
*/
CREATE VIEW vw_rtv_shipment_detail_result_totals AS
    SELECT
        C.*,
        coalesce(D.sum_quantity, 0) AS total_quantity
    FROM
        (SELECT A.rtv_shipment_detail_id, B.type_id, B.type
        FROM
            (SELECT DISTINCT rtv_shipment_detail_id FROM rtv_shipment_detail_result) A
        CROSS JOIN
            (SELECT id AS type_id, type FROM rtv_shipment_detail_result_type) B ) C
    LEFT JOIN
        (SELECT
            rsdr.rtv_shipment_detail_id,
            rsdr.type_id,
            rsdrt.type,
            sum(quantity) AS sum_quantity
        FROM rtv_shipment_detail_result rsdr
        INNER JOIN rtv_shipment_detail_result_type rsdrt
            ON (rsdr.type_id = rsdrt.id)
        GROUP BY rsdr.rtv_shipment_detail_id, rsdr.type_id, rsdrt.type) D
        ON (C.rtv_shipment_detail_id = D.rtv_shipment_detail_id AND C.type_id = D.type_id)
;
GRANT SELECT ON vw_rtv_shipment_detail_result_totals TO www;



/*
* Name      : vw_rtv_shipment_detail_result_totals_row
* Descrip   : Transposed view of vw_rtv_shipment_detail_result_totals
*           : I'd like to generate this dynamically, but I need to read-up
*           : on PL/pgSQL!  I'm sure it'll be much more fun than all that
*           : Transact SQL I used to do so much of :)
*/
CREATE VIEW vw_rtv_shipment_detail_result_totals_row AS
    SELECT
        rtv_shipment_detail_id,
        SUM(CASE type WHEN 'Unknown' THEN total_quantity ELSE 0 END) AS Unknown,
        SUM(CASE type WHEN 'Credited' THEN total_quantity ELSE 0 END) AS Credited,
        SUM(CASE type WHEN 'Repaired' THEN total_quantity ELSE 0 END) AS Repaired,
        SUM(CASE type WHEN 'Replaced' THEN total_quantity ELSE 0 END) AS Replaced,
        SUM(CASE type WHEN 'Dead' THEN total_quantity ELSE 0 END) AS Dead,
        SUM(CASE type WHEN 'Stock Swapped' THEN total_quantity ELSE 0 END) AS Stock_Swapped
    FROM vw_rtv_shipment_detail_result_totals
    GROUP BY rtv_shipment_detail_id
;
GRANT SELECT ON vw_rtv_shipment_detail_result_totals_row TO www;



/*
* Name      : vw_rtv_shipment_details_with_results
* Descrip   : AS vw_rtv_shipment_details but with detail result totals included
*/
CREATE VIEW vw_rtv_shipment_details_with_results AS
    SELECT 
        vw_rsd.*,
        coalesce(vw_rsdrtr.Unknown, 0) AS result_total_unknown,
        coalesce(vw_rsdrtr.Credited, 0) AS result_total_credited,
        coalesce(vw_rsdrtr.Repaired, 0) AS result_total_repaired,
        coalesce(vw_rsdrtr.Replaced, 0) AS result_total_replaced,
        coalesce(vw_rsdrtr.Dead, 0) AS result_total_dead,
        coalesce(vw_rsdrtr.Stock_Swapped, 0) AS result_total_stock_swapped
    FROM vw_rtv_shipment_details vw_rsd
    LEFT JOIN vw_rtv_shipment_detail_result_totals_row vw_rsdrtr
        ON (vw_rsdrtr.rtv_shipment_detail_id = vw_rsd.rtv_shipment_detail_id)
    ;
GRANT SELECT ON vw_rtv_shipment_details_with_results TO www;

--------------------------------------------------------------------------------------------------

/**********************************************************************
* The following views were used during development and may be useful.
* They are not used by the application
***********************************************************************/


/*
* Name      : vw_rtv_quantity_check
* Descrip   : validate rtv_quantity against quantity and list errors
*/
CREATE OR REPLACE VIEW vw_rtv_quantity_check AS
    SELECT *
    FROM
        (SELECT
            q.variant_id AS q_variant_id
        ,   q.location_id AS q_location_id
        ,   lt.type AS q_location_type
        ,   sum(coalesce(q.quantity, 0)) AS q_sum_quantity
        FROM quantity q
        INNER JOIN location l
            ON (q.location_id = l.id)
        INNER JOIN location_type lt
            ON (l.type_id = lt.id)
        WHERE lt.type IN ('RTV Goods In', 'RTV Workstation', 'RTV Process')
        GROUP BY q.variant_id, q.location_id, lt.type) Q
    FULL JOIN
        (SELECT
            rq.variant_id AS rq_variant_id
        ,   rq.location_id AS rq_location_id
        ,   lt.type AS rq_location_type
        ,   sum(coalesce(rq.quantity, 0)) AS rq_sum_quantity
        FROM rtv_quantity rq
        INNER JOIN location l
            ON (rq.location_id = l.id)
        INNER JOIN location_type lt
            ON (l.type_id = lt.id)
        GROUP BY variant_id, location_id, lt.type) RQ
        ON (Q.q_variant_id = RQ.rq_variant_id) AND (Q.q_location_id = RQ.rq_location_id)
    WHERE Q.q_variant_id IS NULL
        OR Q.q_location_id IS NULL
        OR RQ.rq_variant_id IS NULL
        OR RQ.rq_location_id IS NULL
        OR Q.q_sum_quantity <> RQ.rq_sum_quantity
    ORDER BY Q.q_variant_id, Q.q_location_id
;
GRANT SELECT ON vw_rtv_quantity_check TO www;



/*
* Name      : vw_list_rma
* Descrip   : 
*/
CREATE VIEW vw_list_rma AS
    --- stock order items:
    SELECT
        vw_sp.stock_process_id,
        vw_sp.stock_process_type,
        vw_sp.stock_process_status_id,
        vw_sp.stock_process_status,
        vw_dd.delivery_item_id,
        vw_dd.delivery_item_type,
        vw_dd.delivery_item_status,
        vw_pv.variant_id,
        vw_pv.sku,
        vw_pv.designer_id,
        vw_pv.designer,
        vw_pv.style_number,
        vw_pv.colour,
        vw_pv.designer_colour_code,
        vw_pv.designer_colour,
        vw_pv.product_type,
        vw_dd.date AS delivery_date,
        to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI') AS txt_delivery_date,
        vw_sp.quantity
    FROM vw_stock_process vw_sp
    INNER JOIN vw_delivery_details vw_dd
        ON (vw_sp.delivery_item_id = vw_dd.delivery_item_id)
    LEFT JOIN link_delivery_item__stock_order_item lnk_di_soi
        ON (vw_dd.delivery_item_id = lnk_di_soi.delivery_item_id)
    INNER JOIN vw_stock_order_details vw_so
        ON (lnk_di_soi.stock_order_item_id = vw_so.stock_order_item_id)
    INNER JOIN vw_product_variant vw_pv
        ON (vw_so.variant_id = vw_pv.variant_id)
    WHERE vw_sp.complete <> 1
    AND vw_sp.stock_process_type_id = 4	-- 'RTV'
    UNION
    --- return items:
    SELECT
        vw_sp.stock_process_id,
        vw_sp.stock_process_type,
        vw_sp.stock_process_status_id,
        vw_sp.stock_process_status,
        vw_dd.delivery_item_id,
        vw_dd.delivery_item_type,
        vw_dd.delivery_item_status,
        vw_pv.variant_id,
        vw_pv.sku,
        vw_pv.designer_id,
        vw_pv.designer,
        vw_pv.style_number,
        vw_pv.colour,
        vw_pv.designer_colour_code,
        vw_pv.designer_colour,
        vw_pv.product_type,
        vw_dd.date AS delivery_date,
        to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI') AS txt_delivery_date,
        vw_sp.quantity
    FROM vw_stock_process vw_sp
    INNER JOIN vw_delivery_details vw_dd
        ON (vw_sp.delivery_item_id = vw_dd.delivery_item_id)
    LEFT JOIN link_delivery_item__return_item lnk_di_ri
        ON (vw_dd.delivery_item_id = lnk_di_ri.delivery_item_id)
    INNER JOIN vw_return_details vw_r
        ON (lnk_di_ri.return_item_id = vw_r.return_item_id)
    INNER JOIN vw_product_variant vw_pv
        ON (vw_r.variant_id = vw_pv.variant_id)
    WHERE vw_sp.complete <> 1
    AND vw_sp.stock_process_type_id = 4	-- 'RTV'
;
GRANT SELECT ON vw_list_rma TO www;

COMMIT;

