BEGIN;

UPDATE customer_issue_type 
    SET group_id = 7, pws_reason = 'DELIVERY_ISSUE'
    WHERE id = 36;

COMMIT;
