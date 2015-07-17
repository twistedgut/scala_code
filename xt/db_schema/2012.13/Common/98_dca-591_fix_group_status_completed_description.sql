-- DCA-591: Fix description for Putaway Prep Group status: Completed

BEGIN;

UPDATE putaway_prep_group_status
    SET description = 'All items in the group have completed putaway'
    WHERE status = 'Completed';

COMMIT;
