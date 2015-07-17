-- Some shipment boxes shouldn't appear on the ShipmentPacked message. This
-- flag controls that.

BEGIN;
    ALTER TABLE public.shipment_box ADD COLUMN hide_from_iws BOOLEAN DEFAULT false;
COMMIT;
