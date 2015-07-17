
-- Purpose:
--  Recording whether order was placed with a stored credit card

BEGIN;

alter table orders add column used_stored_card boolean default false;

COMMIT;
