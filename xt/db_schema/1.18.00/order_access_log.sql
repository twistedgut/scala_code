-- table to log everyone who views an order

BEGIN;

CREATE TABLE log_order_access (
	id serial primary key,
	orders_id integer not null references orders(id),
	operator_id integer not null references operator(id),
	date timestamp NOT NULL default current_timestamp
);

GRANT ALL ON log_order_access TO www;
GRANT ALL ON log_order_access_id_seq TO www;

COMMIT;

