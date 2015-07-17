-- SHIP-800

BEGIN;

DO $$
DECLARE
    rma_list TEXT[] := ARRAY['U3744714-1587242', 'U3774418-1617650', 'U3852123-1640436', 'U3552728-1629173', 'U3600621-1522677', 'U3899761-1677637', 'U3899761-1677638'];
    val_rma_number              TEXT;
    val_shipment_item_id        INT;
    val_operator_id             INT;
    val_return_item_status_id   INT;
    val_return_item_id          INT;
    val_shipment_item_status_id INT;
    val_shipment_status_id      INT;
    no_returned_items           INT;
    old_quantity                INT;
    new_quantity                INT;
    cancelled_rmas              RECORD;

BEGIN

    FOR i IN array_lower(rma_list,1)..array_upper(rma_list, 1)
    LOOP
        -- Get the operator id
        SELECT id INTO val_operator_id FROM operator WHERE name = 'Application';

        SELECT INTO cancelled_rmas
            r1.id, r1.shipment_id
        FROM return r1
        JOIN link_stock_transfer__shipment lsts ON lsts.shipment_id=r1.shipment_id
        JOIN return r2 ON r1.shipment_id=r2.shipment_id
        JOIN shipment_item si ON si.shipment_id=r1.shipment_id
        WHERE
            r1.return_status_id = (SELECT id FROM return_status WHERE status = 'Cancelled')
            AND r2.return_status_id = (SELECT id FROM return_status WHERE status = 'Complete')
            AND r1.rma_number = rma_list[i]
        GROUP BY r1.id, r1.shipment_id
        ORDER BY r1.id;

        -- SHIPMENTS --
        -- Revert shipment item status
        SELECT id INTO val_shipment_item_status_id FROM shipment_item_status WHERE status = 'Returned';
        UPDATE shipment_item
            SET shipment_item_status_id = val_shipment_item_status_id
            WHERE shipment_id = cancelled_rmas.shipment_id
             RETURNING id INTO val_shipment_item_id;

        -- Log new shipment item status
        INSERT INTO shipment_item_status_log
            (shipment_item_id, shipment_item_status_id, operator_id)
        VALUES
            (val_shipment_item_id, val_shipment_item_status_id, val_operator_id);

        -- CRevert shipment status
        SELECT id INTO val_shipment_status_id FROM shipment_status WHERE status = 'Dispatched';
        UPDATE shipment
            SET shipment_status_id = val_shipment_status_id
            WHERE id = cancelled_rmas.shipment_id;

        -- Log new status of the current shipment
        INSERT INTO shipment_status_log
            (shipment_id, shipment_status_id, operator_id)
        VALUES
            (cancelled_rmas.shipment_id, val_shipment_status_id, val_operator_id);

        RAISE NOTICE 'Cancel rma: %, Shipment ID: %, Shipment item: %', cancelled_rmas.id, cancelled_rmas.shipment_id,val_shipment_item_id;

    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMIT;