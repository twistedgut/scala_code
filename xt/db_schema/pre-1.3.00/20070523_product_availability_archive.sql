BEGIN;

create table product_approval_archive (
id serial,
list text,
created_timestamp timestamp default 'now',
primary key(id)
);

grant all on product_approval_archive_id_seq to www;

grant all on product_approval_archive to www;

alter table product_approval_archive add column operator_id integer not null references operator(id);

alter table product_approval_archive add column title text not null;

COMMIT;
