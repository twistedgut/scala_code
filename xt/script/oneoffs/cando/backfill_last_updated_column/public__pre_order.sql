-- CANDO-8228: Backfill the last_updated column in the public.pre_order
-- table, only where it's NULL.

BEGIN WORK;

    UPDATE  public.pre_order
    SET     last_updated = NOW()
    WHERE   last_updated IS NULL;

COMMIT;
