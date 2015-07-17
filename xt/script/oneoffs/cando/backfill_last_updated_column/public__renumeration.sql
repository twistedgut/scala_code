-- CANDO-8228: Backfill the last_updated column in the public.renumeration
-- table, only where it's NULL.

BEGIN WORK;

    UPDATE  public.renumeration
    SET     last_updated = NOW()
    WHERE   last_updated IS NULL;

COMMIT;
