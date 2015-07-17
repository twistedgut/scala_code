--
-- DC1 ONLY
--
-- CANDO-8454: Can't Create RMA for Jimmy Choo Orders due to tender being out by 0.01
--

BEGIN WORK;

UPDATE orders.tender
    SET value = value + 0.01
WHERE order_id IN (
    SELECT  id
    FROM    orders
    WHERE   order_nr IN (
        'JCHROW0000156929',
        'JCHROW0000118733'
    )
);

INSERT INTO order_note ( orders_id, note, note_type_id, operator_id, date ) VALUES
(
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000156929' ),
    'BAU (CANDO-8454) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
),
(
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000118733' ),
    'BAU (CANDO-8454) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
)
;

COMMIT WORK;
