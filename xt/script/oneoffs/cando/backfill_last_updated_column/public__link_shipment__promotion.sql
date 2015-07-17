-- CANDO-8228: Backfill the last_updated column in the public.link_shipment__promotion
-- table, only where it's NULL.

BEGIN WORK;

    UPDATE  public.link_shipment__promotion
    SET     last_updated = NOW()
    WHERE   last_updated IS NULL;

COMMIT;