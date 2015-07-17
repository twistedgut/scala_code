-- CANDO-7928: ( XTDC3 only ) Cancel PreOrder (P770005173 )

BEGIN WORK;

-- Cancel the Pre-Order, as it's already refunded manually and update the log.

UPDATE pre_order
SET    pre_order_status_id = ( SELECT id from pre_order_status WHERE status = 'Cancelled' )
WHERE  id = 770005173;

INSERT  INTO pre_order_status_log (
            pre_order_id,
            pre_order_status_id,
            operator_id
        )
SELECT  id,
        pre_order_status_id,
        ( SELECT id FROM operator WHERE name = 'Application' )
FROM    pre_order
WHERE   id = 770005173;


-- Cancel the associated pre-order items and update the log.

UPDATE  pre_order_item
SET     pre_order_item_status_id = ( SELECT id FROM pre_order_item_status WHERE status = 'Cancelled' )
WHERE   pre_order_id = 770005173;


INSERT  INTO pre_order_item_status_log (
            pre_order_item_id,
            pre_order_item_status_id,
            operator_id
        )
SELECT  id,
        pre_order_item_status_id,
        ( SELECT id FROM operator WHERE name = 'Application' )
FROM    pre_order_item
WHERE   pre_order_id = 770005173;


-- Add pre-order notes

INSERT  INTO pre_order_note (
    pre_order_id,
    note,
    note_type_id,
    operator_id
) VALUES (
    770005173,
    'CANDO-7928: Cancelling this pre-order without issuing a refund, because it has been refunded manually by Personal Shopping. Customer placed an order (710084800) for the same pid once pid was live.',
    ( SELECT id FROM pre_order_note_type WHERE description = 'Misc' ),
    ( SELECT id FROM operator WHERE name = 'Application' )
);

-- Cancel reservation record associated with pre_order_item and update the log

UPDATE reservation
SET    status_id = ( SELECT id FROM reservation_status WHERE status = 'Cancelled' )
WHERE  id = ( SELECT reservation_id FROM pre_order_item WHERE pre_order_id= 770005173 );

INSERT INTO reservation_log (
    reservation_id,
    reservation_status_id,
    operator_id,
    date,
    quantity,
    balance
) VALUES (
    ( SELECT reservation_id FROM pre_order_item WHERE pre_order_id= 770005173 ),
    ( SELECT id FROM reservation_status WHERE status ='Cancelled' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    now(),
    -1,
    (
        SELECT count(*) FROM reservation WHERE status_id = (
            SELECT id FROM reservation_status WHERE status = 'Uploaded')
        AND variant_id = (
            SELECT variant_id FROM reservation WHERE id = (
                SELECT reservation_id FROM pre_order_item WHERE pre_order_id= 770005173 )
            )
    )
);



COMMIT WORK;


