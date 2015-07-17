-- This patch will add a new boolean field to the 'return_arrival' table
-- and set all rows to TRUE in the table.
-- Then another patch will go through and change some of the those rows to FALSE
-- followed by another patch that will change some of those rows back to TRUE

BEGIN WORK;

ALTER TABLE return_arrival ADD COLUMN goods_in_processed BOOLEAN DEFAULT FALSE
;

UPDATE return_arrival
	SET goods_in_processed = TRUE
;

ALTER TABLE return_arrival ALTER COLUMN goods_in_processed SET NOT NULL
;

UPDATE return_arrival
	SET goods_in_processed = FALSE
WHERE id IN (
	SELECT	me.id
	FROM	public.return_arrival me
			JOIN public.return_delivery return_delivery
				ON return_delivery.id = me.return_delivery_id
			LEFT JOIN public.shipment shipment
				ON shipment.return_airway_bill = me.return_airway_bill
			LEFT JOIN public.return return
				ON return.shipment_id = shipment.id
	WHERE	( ( me.removed = false
				AND	( return.return_status_id = 1
				OR return.return_status_id IS NULL )
	AND		return_delivery.confirmed = true ) )
)
;

UPDATE return_arrival
	SET goods_in_processed = TRUE
WHERE goods_in_processed = FALSE
AND id IN (
	SELECT	me.id
	FROM	public.return_arrival me
			JOIN return_item ri ON ri.return_airway_bill = me.return_airway_bill
			JOIN return_item_status_log risl ON risl.return_item_id = ri.id AND risl.return_item_status_id = 2
			JOIN public.return_delivery return_delivery
				ON return_delivery.id = me.return_delivery_id
			LEFT JOIN public.shipment shipment
				ON shipment.return_airway_bill = me.return_airway_bill
			LEFT JOIN public.return return
				ON return.shipment_id = shipment.id
	WHERE	( ( me.removed = false
				AND ( return.return_status_id = 1
				OR return.return_status_id IS NULL )
	AND		return_delivery.confirmed = true )
	AND		risl.date >= me.date )
)
;

COMMIT WORK;
