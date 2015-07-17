
-- Introduce new column to "putaway_prep_group" table to hold ID of special group
-- that is used instead of PGID/RGID while putting away stock that comes from
-- "Packing exception" as "Cancelled".

BEGIN;

-- Add new column to hold "group" (similar to PGID/Recode ID) for stock that goes
-- into PRL from special location with cancelled items from packing exception
ALTER TABLE putaway_prep_group
    ADD putaway_prep_cancelled_group_id integer NULL;
COMMENT ON COLUMN putaway_prep_group.putaway_prep_cancelled_group_id
    IS 'ID of special "group" for stock that goes to PRL from "Packing exception cancelled location"';

ALTER TABLE putaway_prep_group
    DROP CONSTRAINT putaway_prep_group_check;

-- Add constraint to ensure that row has only one of these be populated:
--      * recode_id
--      * group_id
--      * cancelled_location_group_id
--
ALTER TABLE putaway_prep_group ADD CONSTRAINT putaway_prep_group_check CHECK (
    (recode_id IS NOT NULL AND group_id IS NULL     AND putaway_prep_cancelled_group_id IS NULL)
    OR (recode_id IS NULL  AND group_id IS NOT NULL AND putaway_prep_cancelled_group_id IS NULL)
    OR (recode_id IS NULL  AND group_id IS NULL     AND putaway_prep_cancelled_group_id IS NOT NULL)
);

-- Create sequence to be used for generating new values of "putaway_prep_cancelled_group_id"
CREATE SEQUENCE putaway_prep_group__putaway_prep_cancelled_group_id_seq
    INCREMENT BY 1 NO MAXVALUE NO MINVALUE START WITH 1 CACHE 1;

ALTER SEQUENCE putaway_prep_group__putaway_prep_cancelled_group_id_seq OWNER TO postgres;
GRANT ALL ON SEQUENCE putaway_prep_group__putaway_prep_cancelled_group_id_seq TO postgres;
GRANT ALL ON SEQUENCE putaway_prep_group__putaway_prep_cancelled_group_id_seq TO www;

COMMIT;
