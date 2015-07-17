--
-- DC2 Only
--

-- CANDO-8050: Updates the Order/Shipment Status of Order's:
--21972335
--21988794
--22050370
--22069475
--400882671

BEGIN WORK;

--
-- Update the Order Status for 21972335 and 400882671
--
UPDATE  orders
    SET order_status_id = (
        SELECT  id
        FROM    order_status
        WHERE   status = 'Cancelled'
    )
WHERE   order_nr = '21972335'
AND     channel_id = (
        SELECT  ch.id
        FROM    channel ch
                    JOIN business b ON b.id = ch.business_id
                                   AND b.config_section = 'NAP'
    )
;
UPDATE  orders
    SET order_status_id = (
        SELECT  id
        FROM    order_status
        WHERE   status = 'Cancelled'
    )
WHERE   order_nr = '400882671'
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
                                   AND b.config_section = 'NAP'
        WHERE   order_nr = '21972335'
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
),
(
    (
        SELECT  o.id
        FROM    orders o
                    JOIN channel ch ON ch.id = o.channel_id
                    JOIN business b ON b.id  = ch.business_id
                                   AND b.config_section = 'OUTNET'
        WHERE   order_nr = '400882671'
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
                                   AND b.config_section = 'NAP'
        WHERE   order_nr = '21972335'
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
    'BAU (CANDO-8540) to update Order''s  and Shipment Status to ''Cancelled'' as all Shipment Items were ''Cancelled''.'
),
(
    (
        SELECT  o.id
        FROM    orders o
                    JOIN channel ch ON ch.id = o.channel_id
                    JOIN business b ON b.id  = ch.business_id
                                   AND b.config_section = 'OUTNET'
        WHERE   order_nr = '400882671'
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
    'BAU (CANDO-8540) to update Order''s  and Shipment Status to ''Cancelled'' as all Shipment Items were ''Cancelled''.'

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
WHERE   id in ( 3524995, 3557751 );
;

INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id) VALUES (
    3524995,
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
),
(
    3557751,
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



---------------------------------------
-- Update Corresponsing shipments to be dispatched for orders  21988794,22050370 and 22069475


UPDATE shipment
    SET shipment_status_id = (
            SELECT  id
            FROM    shipment_status
            WHERE   status = 'Dispatched'
        )
WHERE   id in ( 3550890,3661885,3693846)
;

INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id) VALUES (
    3550890,
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
),
(
    3661885,
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
),
(
    3693846,
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

)
;

INSERT INTO order_note (orders_id, note_type_id, operator_id, date, note) VALUES (
    (
        SELECT  orders_id
        FROM    link_orders__shipment
        WHERE   shipment_id = 3550890
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
    'BAU (CANDO-8540): Updated Shipment ''3550890'' from ''Processing'' to ''Dispatched'' as all Shipment Items were already Dispatched.'
),
(
    (
        SELECT  orders_id
        FROM    link_orders__shipment
        WHERE   shipment_id = 3661885
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
    'BAU (CANDO-8540): Updated Shipment ''3661885'' from ''Processing'' to ''Dispatched'' as all Shipment Items were already Dispatched.'
),
(
    (
        SELECT  orders_id
        FROM    link_orders__shipment
        WHERE   shipment_id = 3693846
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
    'BAU (CANDO-8540): Updated Shipment ''3693846'' from ''Processing'' to ''Dispatched'' as all Shipment Items were already Dispatched.'
)
;

COMMIT WORK;
