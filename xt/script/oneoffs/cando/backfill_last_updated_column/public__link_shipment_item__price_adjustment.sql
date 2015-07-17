-- CANDO-8228: Backfill the last_updated column in the public.link_shipment_item__price_adjustment
-- table, only where it's NULL.

BEGIN WORK;

    UPDATE  public.link_shipment_item__price_adjustment
    SET     last_updated = NOW()
    WHERE   last_updated IS NULL;

COMMIT;
