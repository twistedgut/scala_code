-- Purpose:
--  

BEGIN;

create table renumeration_change_log (
	id serial primary key, 
	renumeration_id integer references renumeration(id) not null,
	pre_value decimal(10,2) not null default 0,
	post_value decimal(10,2) not null default 0,
	operator_id integer references operator(id) not null,
	date timestamp not null default current_timestamp
	);

grant all on renumeration_change_log to www;
grant all on renumeration_change_log_id_seq to www;


COMMIT;