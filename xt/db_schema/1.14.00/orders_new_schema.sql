BEGIN;

CREATE SCHEMA orders AUTHORIZATION www;

CREATE TABLE orders.payment_service (
    id              serial      primary key,
    name            text not null,
    module_name     text not null,

    UNIQUE(name),
    UNIQUE(module_name)
);
GRANT ALL ON orders.payment_service TO www;

INSERT INTO orders.payment_service (name,module_name) VALUES 
    ('DataCash','DataCash');


-- FIXME: not ready yet
--CREATE TABLE payment (
--    id                  serial      primary key,
--    order_id            integer
--                        references order(id),
--    payment_service_id  integer
--                        references payment_service(id)
--
--);
--
--GRANT ALL ON payment TO www;
--


COMMIT;

