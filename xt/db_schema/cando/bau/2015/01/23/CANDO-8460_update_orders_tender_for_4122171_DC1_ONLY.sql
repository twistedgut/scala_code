--
-- DC1 Only
--

-- CANDO-8460: Update the 'orders.tender' value for Order
--             4122171 so that an RMA can be created

BEGIN WORK;

--
-- update the 'orders.tender' value
--
UPDATE orders.tender
    SET value = value + 8.75
WHERE order_id IN (
    SELECT  id
    FROM    orders
    WHERE   order_nr = '4122171'
);

--
-- create an Order Note referencing the change
--

INSERT INTO order_note ( orders_id, note, note_type_id, operator_id, date ) VALUES
(
    ( SELECT id FROM orders WHERE order_nr = '4122171' ),
    'BAU (CANDO-8460) Order tender increased by 8.75',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
)
;

COMMIT WORK;
