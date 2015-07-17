-- DCA-45 DCA-427 Table to record putaway progress

BEGIN;

create sequence putaway_prep_status_id_seq
    increment by 1 no maxvalue no minvalue start with 1 cache 1;

create table putaway_prep_status (
    id integer primary key default nextval('putaway_prep_status_id_seq'),
    status varchar(255) not null
);

create sequence putaway_prep_id_seq
    increment by 1 no maxvalue no minvalue start with 1 cache 1;

-- putaway table tracks progress of putaway preparation
create table putaway_prep (
    id integer primary key default nextval('putaway_prep_id_seq'),
    container_id varchar(255) not null references container(id) deferrable,
    user_id varchar(255) not null,
    pgid varchar(255) not null,
    variant_id integer not null references variant(id) deferrable,
    quantity integer not null,
    status_id integer not null references putaway_prep_status(id)
);

-- -- to roll back:
-- drop table putaway_prep;
-- drop sequence putaway_prep_id_seq;
-- drop table putaway_prep_status;
-- drop sequence putaway_prep_status_id_seq;

COMMIT;
