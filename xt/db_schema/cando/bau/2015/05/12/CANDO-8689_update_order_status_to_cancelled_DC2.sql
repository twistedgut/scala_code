--
-- DC2 Only
--

-- CANDO-8689: Update Order Status to Cancelled
--             for DC2 JC Order: JCHUS0000346175

BEGIN WORK;

--
-- Update the Order's Status
--
UPDATE  orders
    SET order_status_id = (
        SELECT  id
        FROM    order_status
        WHERE   status = 'Cancelled'
    )
WHERE   order_nr = 'JCHUS0000346175'
AND     channel_id = (
        SELECT  ch.id
        FROM    channel ch
                    JOIN business b ON b.id = ch.business_id
                                   AND b.config_section = 'JC'
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
                                   AND b.config_section = 'JC'
        WHERE   order_nr = 'JCHUS0000346175'
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
                                   AND b.config_section = 'JC'
        WHERE   order_nr = 'JCHUS0000346175'
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
    'BAU (CANDO-8689) to update Order and Shipment Status to ''Cancelled'' as the Order had been set to Accepted/Processing after it had originaly been ''Cancelled''.'
);


--
-- Update Shipment Status to be 'Cancelled'
--
UPDATE  shipment
    SET shipment_status_id = (
        SELECT  id
        FROM    shipment_status
        WHERE   status = 'Cancelled'
    )
WHERE   id = 3955725
;

--
-- Create a Shipment Status Log entry
--
INSERT INTO shipment_status_log (shipment_id,shipment_status_id,operator_id) VALUES (
    3955725,
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

