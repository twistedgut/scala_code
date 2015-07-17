-- Purpose:
-- Allow Retail and Goods In to add comments at product level and share 
US/UK

BEGIN;

-- instance table holds all instances of XTracker.

drop table instance;

create table instance ( id serial unique, instance varchar(2), primary 
key ( id ) );

insert into instance ( instance ) values ( 'UK' );
insert into instance ( instance ) values ( 'US' );

select * from instance where id in ( 1, 2 );

-- product_comment table holds comments about a product at product level
-- table is designed to sync between all instances of XTracker as long
-- as /etc/xtracker/xtracker.conf is set with the correct local value.
-- [XTracker]
-- instance=UK

create table product_comment (
id serial unique,
product_id integer not null,
comment text not null,
operator_id integer references operator(id),
department_id smallint references department(id),
created_timestamp timestamp with time zone not null,
instance_id integer references instance(id),
primary key ( instance_id, id )
);

grant all on product_comment to www ;
grant all on product_comment to www ;
grant all on product_comment_id_seq to www ;
grant all on instance to www ;
grant all on instance to www ;
grant all on instance_id_seq to www ;


-- Do it!
COMMIT;

