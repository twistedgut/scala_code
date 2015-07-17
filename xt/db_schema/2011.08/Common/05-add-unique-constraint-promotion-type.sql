-- We wanted to generate constants from the promotion_type table but there are
-- duplicate entries <insert rant about db_schema/9999.99> so this patch will
-- add a unique constraint!

-- For complicated reasons it's not simple to [for me] to write an SQL patch to
-- clean up the existing duplicate data so this patch should be run _after_

BEGIN;

-- Add unique constraint
ALTER TABLE promotion_type ADD UNIQUE ( name, channel_id );

COMMIT;
