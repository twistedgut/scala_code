-- DC1 delete items stuck in transit following recode

BEGIN;

DELETE from quantity 
    WHERE variant_id = 4207898 
    AND status_id = (
        SELECT id 
        FROM flow.status 
        WHERE name = 'In transit from IWS'
    );

COMMIT;
