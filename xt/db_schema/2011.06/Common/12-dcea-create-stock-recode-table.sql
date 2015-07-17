-- Create stock_recode table

BEGIN;

CREATE TABLE public.stock_recode (
    id serial,
    variant_id   integer REFERENCES public.variant(id) DEFERRABLE,
    quantity     integer not null,
    complete     boolean not null default false,
    container    varchar(255),
    primary key (id)
);

ALTER TABLE public.stock_recode OWNER to www;

COMMIT;
