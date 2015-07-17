--
-- DC1 Only
--

-- CANDO-8387: Update an Exchange Shipment & its Items
--             to be Dispatched so an RMA can be created


BEGIN WORK;

UPDATE shipment
    SET shipment_status_id = (
            SELECT  id
            FROM    shipment_status
            WHERE   status = 'Dispatched'
        )
WHERE   id = 6080114
;

INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id) VALUES (
    6080114,
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

UPDATE shipment_item
    SET shipment_item_status_id = (
            SELECT  id
            FROM    shipment_item_status
            WHERE   status = 'Dispatched'
        )
WHERE   shipment_id = 6080114
;

INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
SELECT  si.id,
        sis.id,
        op.id
FROM    shipment_item si,
        shipment_item_status sis,
        operator op
WHERE   si.shipment_id = 6080114
AND     sis.status = 'Dispatched'
AND     op.name = 'Application'
;

INSERT INTO order_note (orders_id, note_type_id, operator_id, date, note) VALUES (
    (
        SELECT  orders_id
        FROM    link_orders__shipment
        WHERE   shipment_id = 6080114
    ),
    (
        SELECT  id
        FROM    note_type
        WHERE   description = 'Returns'
    ),
    (
        SELECT  id
        FROM    operator
        WHERE   name = 'Application'
    ),
    now(),
    'BAU (CANDO-8387): Updated Exchange Shipment ''6080114'' and its Item to be ''Dispatched'' from ''Cancelled'', so that an RMA with a ZERO Refund can be created to put the Stock back.'
)
;

COMMIT WORK;
