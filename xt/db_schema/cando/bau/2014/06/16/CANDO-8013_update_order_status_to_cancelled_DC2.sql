--
-- DC2 Only
--

-- CANDO-8013: Updates the Order Status of 21722781
--             to 'Cancelled' from 'Credit Check'

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
WHERE   order_nr = '21722781'
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
        WHERE   order_nr = '21722781'
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
        WHERE   order_nr = '21722781'
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
    'BAU (CANDO-8013) to update Order''s Status back to ''Cancelled'' after it was placed on ''Credit Check''.'
);

COMMIT WORK;
