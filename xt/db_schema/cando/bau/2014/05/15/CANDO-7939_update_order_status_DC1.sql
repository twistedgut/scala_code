--
-- For DC1 Only
--

-- CANDO-7939: Update Order: 3579362 status to
--             be Cancelled plus Log & Note it

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
WHERE   order_nr = '3579362'
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
        WHERE   order_nr = '3579362'
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
        WHERE   order_nr = '3579362'
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
    'BAU (CANDO-7938) to update Order''s Status to ''Cancelled'' as it was put on ''Credit Check'' after the Order was Cancelled.'
);

COMMIT WORK;
