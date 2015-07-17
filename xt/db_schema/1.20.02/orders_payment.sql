
-- create new table to store order payments taken via central Payment service

BEGIN;

-- orders schema should have been created by earlier patch
-- but it wasn't applied to live in error
-- create it again if needed

CREATE SCHEMA orders AUTHORIZATION www;

COMMIT;

BEGIN;

CREATE TABLE orders.payment (
    id serial primary key,
    orders_id integer NOT NULL references public.orders(id) unique,
    psp_ref varchar(255) NOT NULL unique,
    preauth_ref varchar(255) NOT NULL unique,
    settle_ref varchar(255) NULL,
    fulfilled boolean DEFAULT false NOT NULL,
    valid boolean DEFAULT true NOT NULL
);

GRANT ALL ON orders.payment TO www;
GRANT ALL ON orders.payment_id_seq TO www;

COMMIT;
