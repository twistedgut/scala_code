BEGIN;

-- whm-3700: add new statuses from faulty returns

INSERT INTO return_item_status(status) VALUES('Failed QC - Fixed');
INSERT INTO return_item_status(status) VALUES('Failed QC - RTV');
INSERT INTO return_item_status(status) VALUES('Failed QC - DeadStock');

COMMIT;
