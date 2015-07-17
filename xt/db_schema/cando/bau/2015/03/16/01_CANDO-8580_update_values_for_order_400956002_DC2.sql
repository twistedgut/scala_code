-- DC2 Only

-- CANDO-8580: Update the Unit Price & Tax values for both Shipment Items of Order:
--             400956002 to their original Values because they had been set to ZERO


BEGIN WORK;


--
-- Update Item for SKU: 448008-012
--

UPDATE shipment_item
    SET unit_price = 513.00,
        tax        = 180.58
WHERE   variant_id IN (
    SELECT  id
    FROM    variant
    WHERE   product_id = 448008
    AND     size_id = 12
)
AND     shipment_id = 3882788
;

--
-- Update Item for SKU: 556198-099
--

UPDATE shipment_item
    SET unit_price = 445.50,
        tax        = 156.82
WHERE   variant_id IN (
    SELECT  id
    FROM    variant
    WHERE   product_id = 556198
    AND     size_id = 99
)
AND     shipment_id = 3882788
;


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
        WHERE   order_nr = '400956002'
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
    'BAU (CANDO-8580): to update both the Shipment Item''s Unit Price & Tax to their Original Values as they had been set to ZERO'
);


COMMIT WORK;
