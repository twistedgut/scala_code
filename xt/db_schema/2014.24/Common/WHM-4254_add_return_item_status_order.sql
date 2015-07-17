-- Add a column to sort return item statuses for display

BEGIN;
    ALTER TABLE delivery_action ADD rank INT;

    COMMENT ON COLUMN delivery_action.rank IS 'Order in which to display the actions for the user';

    UPDATE delivery_action SET rank = 10 WHERE action = 'Create';
    UPDATE delivery_action SET rank = 20 WHERE action = 'Count';
    UPDATE delivery_action SET rank = 30 WHERE action = 'Check';
    UPDATE delivery_action SET rank = 40 WHERE action = 'Approve';
    UPDATE delivery_action SET rank = 50 WHERE action = 'Bag and Tag';
    UPDATE delivery_action SET rank = 60 WHERE action = 'Putaway';
    UPDATE delivery_action SET rank = 70 WHERE action = 'Putaway Prep';
    UPDATE delivery_action SET rank = 80 WHERE action = 'Cancel';
    UPDATE delivery_action SET rank = 90 WHERE action = 'Held';
    UPDATE delivery_action SET rank = 100 WHERE action = 'Released';

    ALTER TABLE delivery_action
        ALTER COLUMN action SET NOT NULL,
        ADD UNIQUE (action),
        ALTER COLUMN rank SET NOT NULL,
        ADD UNIQUE (rank);

COMMIT;
