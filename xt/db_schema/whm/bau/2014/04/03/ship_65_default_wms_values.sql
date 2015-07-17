
-- Fix nom day shipments with incorrect wms_deadline
UPDATE shipment SET wms_deadline = (nominated_earliest_selection_time + INTERVAL '2 HOUR')
    WHERE shipment_status_id IN (
        SELECT id FROM shipment_status WHERE status IN (
            'Finance Hold',
            'Processing',
            'Hold',
            'Return Hold',
            'Exchange Hold',
            'DDU Hold',
            'Pre-Order Hold'
        )
    )
    AND nominated_earliest_selection_time IS NOT NULL
    AND wms_bump_pick_priority IS NOT NULL;

-- Fill in some default wms settings for shipments that need them
UPDATE shipment SET wms_deadline = sla_cutoff
    WHERE shipment_status_id IN (
        SELECT id FROM shipment_status WHERE status IN (
            'Finance Hold',
            'Processing',
            'Hold',
            'Return Hold',
            'Exchange Hold',
            'DDU Hold',
            'Pre-Order Hold'
        )
    )
    AND wms_deadline IS NULL
    AND sla_cutoff IS NOT NULL;

UPDATE shipment SET wms_initial_pick_priority = 20
    WHERE shipment_status_id IN (
        SELECT id FROM shipment_status WHERE status IN (
            'Finance Hold',
            'Processing',
            'Hold',
            'Return Hold',
            'Exchange Hold',
            'DDU Hold',
            'Pre-Order Hold'
        )
    )
    AND wms_initial_pick_priority IS NULL
    AND sla_cutoff IS NOT NULL;

-- This is filling in blanks and also fixing before-mentioned nom day shipments
UPDATE shipment
    SET wms_bump_pick_priority = 3,
    wms_bump_deadline = (sla_cutoff - INTERVAL '2 HOUR')
    WHERE shipment_status_id IN (
        SELECT id FROM shipment_status WHERE status IN (
            'Finance Hold',
            'Processing',
            'Hold',
            'Return Hold',
            'Exchange Hold',
            'DDU Hold',
            'Pre-Order Hold'
        )
    )
    AND nominated_delivery_date IS NOT NULL
    AND sla_cutoff IS NOT NULL;
