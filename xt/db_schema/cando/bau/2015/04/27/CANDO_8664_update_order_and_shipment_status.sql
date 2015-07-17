--
-- DC2 Only
--

-- CANDO-8664: Updates the Order/Shipment Status of Order: 22205726

BEGIN WORK;

--
-- Update the Order Status
--
UPDATE  orders
    SET order_status_id = (
        SELECT  id
        FROM    order_status
        WHERE   status = 'Accepted'
    )
WHERE   order_nr = '22205726'
AND     channel_id = (
        SELECT  ch.id
        FROM    channel ch
                    JOIN business b ON b.id = ch.business_id
                                   AND b.config_section = 'NAP'
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
                                   AND b.config_section = 'NAP'
        WHERE   order_nr = '22205726'
    ),
    (
        SELECT  id
        FROM    order_status
        WHERE   status = 'Accepted'
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
                                   AND b.config_section = 'NAP'
        WHERE   order_nr = '22205726'
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
    'BAU (CANDO-8664) to update Order to ''Accepted'' and Shipment Status to ''Dispatched'' as somehow the Order was ''Cancelled''.'
);

--
-- update Shipment status to 'Dispatched'
--
UPDATE shipment
    SET shipment_status_id = (
            SELECT  id
            FROM    shipment_status
            WHERE   status = 'Dispatched'
        )
WHERE   id=3965081
;

INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id) VALUES (
    3965081,
    (
        SELECT  id
        FROM    shipment_status
        WHERE   status = 'Dispatched'
    ),
    (
        SELECT  id
        FROM    operator
        WHERE   name = 'Application'
    )
);

COMMIT WORK;
