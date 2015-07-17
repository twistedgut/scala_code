-- Purpose: Recording the origin of PI counts (Picking, Returns or Manual counting)
--  

BEGIN;

-- Create lookup table of count origins
create table stock_count_origin (
	id serial primary key,
	origin varchar(255) not null,
	unique(origin)
	);

grant all on stock_count_origin to www;
grant all on stock_count_origin_id_seq to www;

insert into stock_count_origin values(default, 'Manual');
insert into stock_count_origin values(default, 'Picking');
insert into stock_count_origin values(default, 'Returns');

-- add origin to the stock count table
alter table stock_count add column origin_id integer references stock_count_origin(id) null;


COMMIT;