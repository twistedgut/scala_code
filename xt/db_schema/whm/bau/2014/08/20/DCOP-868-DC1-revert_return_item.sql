-- Somehow this return item is out of sync with its stock process item, revert
-- the item status so it's in sync again and let's see if we can put this away.

BEGIN;
    UPDATE return_item
        SET return_item_status_id = (
            SELECT id FROM return_item_status WHERE status = 'Failed QC - Rejected'
        )
        WHERE id = 3799057;
    INSERT INTO return_item_status_log (return_item_id, return_item_status_id, operator_id)
        VALUES (
            3799057,
            (SELECT id FROM return_item_status WHERE status = 'Failed QC - Rejected'),
            (SELECT id FROM operator WHERE name = 'Application')
        );
COMMIT;
