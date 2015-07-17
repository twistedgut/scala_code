
/*
    DCA-3001

    Cleanup container and shipment_item table from
    issues happened at packing.

    Unties shipment items from containers if shipment
    items is in the status that does not involve containers.

    For containers that are not associated with any shipment
    item clean up their fields used only in packing.
*/

BEGIN;

/*
    Untie shipment items from containers if shipment
    items is in statuses that do not evolve containers.

    Shipment items are associated with container only when
    they are in statuses: Picked, Cancel Pending, Packing Exception.
*/
UPDATE shipment_item
SET container_id = NULL
WHERE id IN (
    SELECT id
    FROM shipment_item
    WHERE container_id IS NOT NULL
      AND shipment_item_status_id NOT IN (3,9,13)
);


/*
    Update container's packing related fields to be NULL
    if container is not associated with any shipment item
*/
UPDATE container
SET pack_lane_id      = NULL,
    routed_at         = NULL,
    arrived_at        = NULL,
    physical_place_id = NULL
WHERE id NOT IN (
    SELECT DISTINCT container_id
    FROM shipment_item
    WHERE container_id IS NOT NULL
)
AND (
     pack_lane_id         IS NOT NULL
     OR routed_at         IS NOT NULL
     OR arrived_at        IS NOT NULL
     OR physical_place_id IS NOT NULL
);

COMMIT;

