-- CANDO-8228: Backfill the last_updated column in the public.reservation
-- table, only where it's NULL.

BEGIN WORK;

    UPDATE  public.reservation
    SET     last_updated = NOW()
    WHERE   last_updated IS NULL;

COMMIT;
