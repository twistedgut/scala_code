--
-- CANDO-8120: Fix missing pre_order_payment and update PreOrder status to Complete for 770005904
--
-- TO BE RUN ON XTDC3 ONLY
--NB. This ticket has part-2 which got missed. Please refer : db_schema/cando/bau/2014/08/06/CANDO-8144_fix_pre_order_reservation.sql

BEGIN WORK;

INSERT INTO pre_order_payment (
        pre_order_id,
        preauth_ref,
        settle_ref,
        psp_ref
    )
    VALUES (
        770005904,
        '9046255',
        '7482584',
        '3500103467806138'
    );

UPDATE pre_order
    SET pre_order_status_id = (
        SELECT id FROM pre_order_status WHERE status = 'Complete'
    )
    WHERE id = 770005904;

UPDATE pre_order_item
    SET pre_order_item_status_id = (
        SELECT id FROM pre_order_item_status WHERE status = 'Complete'
    )
    WHERE pre_order_id = 770005904;

INSERT INTO pre_order_note (
        pre_order_id,
        note,
        note_type_id,
        operator_id,
        date
    )
    VALUES (
        770005904,
        'Payment record in XT manually updated and status set to Complete by BAU (CANDO-8120)',
        ( SELECT id from note_type WHERE description = 'Order' ),
        ( SELECT id FROM operator WHERE name = 'Application' ),
        now()
    );

COMMIT;
