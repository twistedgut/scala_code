-- This patch is to resolve: http://animal:8080/browse/XPM-154

BEGIN WORK;

    -- Europe/London is BST not GMT
    UPDATE  promotion.target_city
    SET     name='BST (London)',
            display_order=0
    WHERE   name='GMT (London)';

    -- add an explicit GMT
    INSERT  INTO promotion.target_city
    (id, name, timezone, display_order)
    VALUES
    (0, 'GMT/UTC', 'UTC', 1);

COMMIT;
