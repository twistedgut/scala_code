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
            r1.id, r1.shipment_id, q.variant_id
        FROM return r1
        JOIN link_stock_transfer__shipment lsts ON lsts.shipment_id=r1.shipment_id
        JOIN return r2 ON r1.shipment_id=r2.shipment_id
        JOIN shipment_item si ON si.shipment_id=r1.shipment_id
        JOIN quantity q ON q.variant_id=si.variant_id
        WHERE q.status_id = (SELECT id FROM flow.status WHERE name = 'Transfer Pending')
            AND r1.return_status_id = (SELECT id FROM return_status WHERE status = 'Cancelled')
            AND r2.return_status_id = (SELECT id FROM return_status WHERE status = 'Complete')
            AND q.location_id = (SELECT id FROM location WHERE location = 'Transfer Pending')
            AND r1.rma_number = rma_list[i]
        ORDER BY r1.id;

        IF cancelled_rmas.id IS NULL THEN
        SELECT INTO cancelled_rmas
            r1.id, r1.shipment_id, q.variant_id
        FROM return r1
        JOIN link_stock_transfer__shipment lsts ON lsts.shipment_id=r1.shipment_id
        JOIN return r2 ON r1.shipment_id=r2.shipment_id
        JOIN shipment_item si ON si.shipment_id=r1.shipment_id
        JOIN quantity q ON q.variant_id=si.variant_id
        WHERE r1.return_status_id = (SELECT id FROM return_status WHERE status = 'Cancelled')
            AND r2.return_status_id = (SELECT id FROM return_status WHERE status = 'Complete')
            AND r1.rma_number = rma_list[i]
        GROUP BY r1.id, r1.shipment_id, q.variant_id
        ORDER BY r1.id;
        END IF;

        RAISE NOTICE 'Started processing rma: %', rma_list[i];

        CONTINUE WHEN cancelled_rmas.id IS NULL;
        -- RETURNS --
        -- This was done in the first part of the ticket but I will add this here
        -- commented out just to know that this need to be done also
        -- UPDATE return SET cancellation_date = current_timestamp, return_status_id = (SELECT id FROM return_status WHERE status = 'Cancelled')
        -- WHERE id = cancelled_rmas.id;

        -- Log the cancellation of the return
        INSERT INTO return_status_log (return_id, return_status_id, operator_id )
        VALUES (
            cancelled_rmas.id,
            ( SELECT id FROM return_status WHERE status = 'Cancelled' ),
            val_operator_id
        );

        -- Cancel return items
        SELECT id INTO val_return_item_status_id FROM return_item_status WHERE status = 'Cancelled';
        SELECT COUNT(*) INTO no_returned_items FROM return_item WHERE return_id = cancelled_rmas.id;
        UPDATE return_item
        SET return_item_status_id = val_return_item_status_id
        WHERE return_id = cancelled_rmas.id
            RETURNING id INTO val_return_item_id;

        --Log the cancellation of the return item
        INSERT INTO return_item_status_log
            (return_item_id, return_item_status_id, operator_id)
        VALUES
            (val_return_item_id, val_return_item_status_id, val_operator_id);

        -- QUANTITY --
        SELECT quantity INTO old_quantity FROM quantity
        WHERE status_id = (SELECT id FROM flow.status WHERE name = 'Transfer Pending')
            AND location_id = (SELECT id FROM location WHERE location = 'Transfer Pending')
            AND variant_id = cancelled_rmas.variant_id;

        CONTINUE WHEN old_quantity IS NULL;

        new_quantity := old_quantity - no_returned_items;

        INSERT INTO log_sample_adjustment (
            sku, location_name, operator_name, channel_id, notes, delta, balance
        )
        SELECT v.product_id || '-' || sku_padding(v.size_id),
            l.location,
            'Application',
            q.channel_id,
            'Adjusted by BAU to fix error',
            -no_returned_items,
            new_quantity
        FROM variant v
        JOIN quantity q ON v.id=q.variant_id
        JOIN location l ON q.location_id=l.id
        WHERE l.location = 'Transfer Pending'
            AND q.status_id = (SELECT id FROM flow.status WHERE name = 'Transfer Pending')
            AND v.id = cancelled_rmas.variant_id;

        IF new_quantity > 0 THEN
            UPDATE quantity
            SET quantity = new_quantity
            WHERE
                status_id = (SELECT id FROM flow.status WHERE name = 'Transfer Pending')
                AND location_id = (SELECT id FROM location WHERE location = 'Transfer Pending')
                AND quantity   = old_quantity
                AND variant_id = cancelled_rmas.variant_id;
        ELSE
            DELETE FROM quantity
            WHERE status_id = (SELECT id FROM flow.status WHERE name = 'Transfer Pending')
                AND location_id = (SELECT id FROM location WHERE location = 'Transfer Pending')
                AND quantity = old_quantity
                AND variant_id = cancelled_rmas.variant_id;
        END IF;

        RAISE NOTICE 'Cancel rma: %, Variant ID: %, New quantity: %', cancelled_rmas.id, cancelled_rmas.variant_id, no_returned_items;

    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMIT;