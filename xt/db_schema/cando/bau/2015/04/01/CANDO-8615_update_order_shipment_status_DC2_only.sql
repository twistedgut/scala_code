--
-- DC2 Only
--

-- CANDO-8615: Updates the Order/Shipment Status of Order :400964995

BEGIN WORK;

--
-- Update the Order Status
--
UPDATE  orders
    SET order_status_id = (
        SELECT  id
        FROM    order_status
        WHERE   status = 'Cancelled'
    )
WHERE   order_nr = '400964995'
AND     channel_id = (
        SELECT  ch.id
        FROM    channel ch
                    JOIN business b ON b.id = ch.business_id
                                   AND b.config_section = 'OUTNET'
    )
;

--
-- Insert a Log entry into 'order_status_log'
--
INSERT INTO order_status_log (orders_id, order_status_id, operator_id) VALUES (
    (
        SELECT  o.id
        FROM    orders o
                    JOIN channel ch ON ch.id = o.channel_id
                    JOIN business b ON b.id  = ch.business_id
                                   AND b.config_section = 'OUTNET'
        WHERE   order_nr = '400964995'
    ),
    (
        SELECT  id
        FROM    order_status
        WHERE   status = 'Cancelled'
    ),
    (
        SELECT  id
        FROM    operator
        WHERE   name = 'Application'
    )
);

--
-- Insert an Order Note into 'order_note'
--
INSERT INTO order_note (orders_id, note_type_id, operator_id, date, note ) VALUES (
    (
        SELECT  o.id
        FROM    orders o
                    JOIN channel ch ON ch.id = o.channel_id
                    JOIN business b ON b.id  = ch.business_id
                                   AND b.config_section = 'OUTNET'
        WHERE   order_nr = '400964995'
    ),
    (
        SELECT  id
        FROM    note_type
        WHERE   description = 'Order'
    ),
    (
        SELECT  id
        FROM    operator
        WHERE   name = 'Application'
    ),
    now(),
    'BAU (CANDO-8615) to update Order and Shipment Status to ''Cancelled''.'
);

--
-- update Shipment status to 'Cancelled'
--
UPDATE shipment
    SET shipment_status_id = (
            SELECT  id
            FROM    shipment_status
            WHERE   status = 'Cancelled'
        )
WHERE   id=3907962;
;

INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id) VALUES (
    3907962,
    (
        SELECT  id
        FROM    shipment_status
        WHERE   status = 'Cancelled'
    ),
    (
        SELECT  id
        FROM    operator
        WHERE   name = 'Application'
    )
)
;

COMMIT WORK;
