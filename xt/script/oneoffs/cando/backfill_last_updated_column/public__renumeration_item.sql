-- CANDO-8228: Backfill the last_updated column in the public.renumeration_item
-- table, only where it's NULL.

BEGIN WORK;

    UPDATE  public.renumeration_item
    SET     last_updated = NOW()
    WHERE   last_updated IS NULL;

COMMIT;
