-- Purpose:
--  Add a boolean "domestic" field to shipping_zone, meaning that the zone is within the country we are shipping from.
--  This will remove the need for hardcoding from XTracker::Order::Actions::CreateNewShipment and thus allow more harmonisation between US and INTL
--  This update is for the Intl database. Run shipping_zone_patch_us.sql for the US database.
BEGIN;

ALTER TABLE shipping_zone ADD COLUMN domestic BOOLEAN DEFAULT FALSE NOT NULL;
UPDATE shipping_zone SET domestic=TRUE WHERE id <= 4 AND id > 0;

COMMIT;