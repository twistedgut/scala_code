BEGIN;

-- Table to hold audit log for various columns

CREATE TABLE audit.recent (
    id serial PRIMARY KEY,
    table_schema text not null,
    table_name text not null,
    col_name text not null,
    col_type text not null,
    audit_id int not null,
    descriptor text null,
    descriptor_value text null,
    old_val text,
    new_val text,
    operator_id int null references public.operator(id),
    timestamp timestamp with time zone not null default now()
);

ALTER TABLE audit.recent OWNER TO www;
ALTER SEQUENCE audit.recent_id_seq OWNER TO www;

COMMIT;
