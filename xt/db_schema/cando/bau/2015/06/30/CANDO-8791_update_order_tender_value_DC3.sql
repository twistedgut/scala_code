--
-- DC3 Only
--

-- CANDO-8791: Updates 'orders.tender' for Credit Card
--             to '1,640,834.80' as Frontend had only
--             passed 1 million in XML file


BEGIN WORK;

--
-- update the 'orders.tender' value
--
UPDATE orders.tender
    SET value = 1640834.80
WHERE order_id = (
    SELECT  id
    FROM    orders
    WHERE   order_nr = '710383774'
)
AND   type_id = (
    SELECT  id
    FROM    renumeration_type
    WHERE   type = 'Card Debit'
)
;

--
-- create an Order Note referencing the change
--
INSERT INTO order_note ( orders_id, note, note_type_id, operator_id, date ) VALUES
(
    ( SELECT id FROM orders WHERE order_nr = '710383774' ),
    'BAU (CANDO-8791): Credit Card Order tender updated to ''1,640,834.80'' as it was originally set to just 1 million.',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
)
;

COMMIT WORK;
