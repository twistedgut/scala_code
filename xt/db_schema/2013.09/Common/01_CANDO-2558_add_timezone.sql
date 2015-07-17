-- CANDO-2558: Add timezone to renumeration_status_log and shipment_status_log date columns

BEGIN;

	--Add timezone to renumeration_status_log
	 ALTER TABLE renumeration_status_log ALTER COLUMN date TYPE timestamp with time zone;

	--Add timezone to shipment_status_log
	ALTER TABLE shipment_status_log  ALTER COLUMN date TYPE timestamp with time zone;

COMMIT;
