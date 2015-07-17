--
-- CANDO-1549 Blitheringly obviously missing indexes
--

BEGIN WORK;

CREATE
 INDEX idx_shipment_email_log_shipment
    ON shipment_email_log(shipment_id)
     ;

CREATE
 INDEX idx_order_note_order_note_type
    ON order_note(orders_id,note_type_id)
     ;

COMMIT WORK;
