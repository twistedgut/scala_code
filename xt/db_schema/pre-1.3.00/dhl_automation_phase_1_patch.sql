-- Purpose:
--  

BEGIN;


-- Add destination code field to the shipment table
alter table shipment add column destination_code varchar(3) null;


-- Create log table for routing requests
create table routing_request_log (
	id serial primary key, 
	date timestamp NOT NULL,
	shipment_id integer references shipment(id) NOT NULL,
	error_code varchar(255) NOT NULL,
	error_message varchar(255) NOT NULL
	);

grant all on routing_request_log to www;
grant all on routing_request_log_id_seq to www;

-- move customer care managers into a new department - used to limit access to create refunds
update operator set department_id = 19 where name = 'Angelina Cecchetto';
update operator set department_id = 19 where name = 'Edson Sarabia';
update operator set department_id = 19 where name = 'Nigel Stephens';
update operator set department_id = 19 where name = 'Stephane Royer';
update operator set department_id = 19 where name = 'Cristina Ubbizzoni';
update operator set department_id = 19 where name = 'Maria Urquia';
update operator set department_id = 19 where name = 'Benedicte Montagnier';

COMMIT;