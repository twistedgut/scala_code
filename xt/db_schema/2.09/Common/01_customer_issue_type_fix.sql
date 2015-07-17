BEGIN;

  UPDATE customer_issue_type
     SET pws_reason = 'INCORRECT_ITEM'
   WHERE description = 'Incorrect item'
     AND group_id = 7;

COMMIT;
