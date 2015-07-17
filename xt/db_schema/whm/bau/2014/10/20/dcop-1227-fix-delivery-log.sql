BEGIN;

update log_delivery set quantity = 0 where delivery_id=2770348 and delivery_action_id = 2;

COMMIT;
