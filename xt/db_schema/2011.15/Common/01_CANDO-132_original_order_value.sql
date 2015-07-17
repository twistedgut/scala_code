-- CANDO -132 -

BEGIN;

-- Add total original order value for order to orders table

alter table orders add column pre_auth_total_value numeric(10,3) ;


COMMIT;

