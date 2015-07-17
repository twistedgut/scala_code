--
-- DC1 ONLY
--
-- CANDO-8442: Update orders.tender to fix out by 0.01 for JCHROW0000127962
--

BEGIN WORK;

UPDATE orders.tender
    SET value = value + 0.01
    WHERE order_id IN (
        SELECT id FROM orders WHERE order_nr IN (
            'JCHROW0000127962',
            'JCHROW0000115439',
            'JCHROW0000131927',
            'JCHROW0000155626',
            'JCHROW0000125335',
            'JCHROW0000146269',
            'JCHROW0000133848',
            'JCHROW0000146250'
        )
    );

INSERT INTO order_note (
    orders_id,
    note,
    note_type_id,
    operator_id,
    date )
VALUES (
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000127962' ),
    'BAU (CANDO-8442) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
),
(
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000133848 ' ),
    'BAU (CANDO-8442) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
),
(
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000146269' ),
    'BAU (CANDO-8442) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
),
(
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000125335' ),
    'BAU (CANDO-8442) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
),
(
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000115439' ),
    'BAU (CANDO-8442) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
),
(
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000131927' ),
    'BAU (CANDO-8442) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
),
(
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000155626' ),
    'BAU (CANDO-8442) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
),
(
    ( SELECT id FROM orders WHERE order_nr = 'JCHROW0000146250' ),
    'BAU (CANDO-8442) Order tender updated to fix out by 0.01',
    ( SELECT id FROM note_type WHERE description = 'Order' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now()
);

COMMIT WORK;
