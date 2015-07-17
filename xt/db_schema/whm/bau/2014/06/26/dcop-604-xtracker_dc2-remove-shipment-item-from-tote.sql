-- DC2 remove shipment_item from tote

BEGIN;

    -- Update shipment_item container to null
    UPDATE shipment_item SET container_id = null WHERE shipment_id = 3030725;

COMMIT;
