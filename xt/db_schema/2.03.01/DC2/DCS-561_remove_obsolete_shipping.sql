BEGIN;

delete from state_shipping_charge where shipping_charge_id in (select id from shipping_charge where description like '%1-2 Day Delivery%');

COMMIT;