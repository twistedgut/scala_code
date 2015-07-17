-- Modify existing price adjustment timings to GMT timings and alter the date_start and date_finish to include timezone
BEGIN;

update price_adjustment set date_start = date_start AT TIME ZONE 'Europe/London';
update price_adjustment set date_start = date_finish AT TIME ZONE 'Europe/London';

ALTER TABLE price_adjustment alter COLUMN date_start type timestamp with time zone;
ALTER TABLE price_adjustment alter COLUMN date_finish type timestamp with time zone;

COMMIT;
