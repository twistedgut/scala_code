-- CANDO-8228: Backfill the last_updated column in the orders.payment
-- table, only where it's NULL.

BEGIN WORK;

    UPDATE  orders.payment
    SET     last_updated = NOW()
    WHERE   last_updated IS NULL;

COMMIT;
