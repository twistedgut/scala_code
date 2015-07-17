-- XTR-890
-- http://jira:8080/browse/XTR-890
--
-- Promotions are showing "freeze customers" on the summary page for no reason


BEGIN;

    -- anything thats "UNKNOWN" but has been exported ...
    UPDATE  promotion.detail
    SET     status_id =
                (SELECT id FROM promotion.status WHERE name='Exported To PWS')
    WHERE   status_id =
                (SELECT id FROM promotion.status WHERE name='UNKNOWN')
    AND     been_exported = true
    ;

    -- anything thats "UNKNOWN" but has been disabled ...
    UPDATE  promotion.detail
    SET     status_id =
                (SELECT id FROM promotion.status WHERE name='Disabled')
    WHERE   status_id =
                (SELECT id FROM promotion.status WHERE name='UNKNOWN')
    AND     enabled = false
    ;

    -- everything else with status "UNKNOWN" should at least be "In Progress"
    UPDATE  promotion.detail
    SET     status_id =
                (SELECT id FROM promotion.status WHERE name='In Progress')
    WHERE   status_id =
                (SELECT id FROM promotion.status WHERE name='UNKNOWN')
    ;

COMMIT;
