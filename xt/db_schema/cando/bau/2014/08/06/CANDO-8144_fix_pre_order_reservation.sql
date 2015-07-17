--
-- CANDO-8144: Insert reservation record for PreOrder 770005921, PreOrder 770005904
--
-- TO BE RUN ON XTDC3 ONLY
--
BEGIN WORK;

--
-- PreOrder 770005921
--

INSERT INTO reservation (
        ordering_id,
        variant_id,
        customer_id,
        operator_id,
        status_id,
        notified,
        channel_id,
        date_created,
        reservation_source_id
    )
    VALUES (
        0,
        4478452,
        26386,
        ( select id from operator where username='o.kolesnichenko'),
        ( select id from reservation_status where status='Pending'),
        'f',
        ( select id from channel where  web_name ='NAP-APAC'),
        '2014-08-04 23:46:19.95179',
        20
    );

UPDATE pre_order_item set reservation_id = (
    SELECT id FROM reservation WHERE
        ordering_id = 0 AND
        variant_id = 4478452 AND
        customer_id= 26386 AND
        operator_id = ( select id from operator where username='o.kolesnichenko') AND
        notified ='f' AND
        status_id=( select id from reservation_status where status='Pending') AND
        channel_id = ( select id from channel where  web_name ='NAP-APAC') AND
        reservation_source_id=20 AND
        id not in ( select reservation_id from pre_order_item  where reservation_id is not null)
    )
    WHERE pre_order_id=770005921;


INSERT INTO pre_order_status_log ( pre_order_id,pre_order_status_id,operator_id,date ) VALUES (
    770005921,
    ( SELECT id FROM pre_order_status WHERE status = 'Complete' ),
    ( SELECT operator_id FROM pre_order WHERE id = 770005921 ),
    '2014-08-04 23:46:19.95179'
);

INSERT INTO pre_order_item_status_log ( pre_order_item_id, pre_order_item_status_id, operator_id, date ) VALUES (
    ( SELECT id FROM pre_order_item WHERE pre_order_id = 770005921 ),
    ( SELECT id FROM pre_order_item_status WHERE status = 'Complete' ),
    ( SELECT operator_id FROM pre_order WHERE id = 770005921 ),
    '2014-08-04 23:46:19.95179'
);


--
--  PreOrder 770005904
--


INSERT INTO reservation (
        ordering_id,
        variant_id,
        customer_id,
        operator_id,
        status_id,
        notified,
        channel_id,
        date_created,
        reservation_source_id
    )
    VALUES (
        0,
        4310608,
        160,
        ( select id from operator where name='Anastasija Grigorjeva'),
        ( select id from reservation_status where status='Pending'),
        'f',
        ( select id from channel where  web_name ='NAP-APAC'),
        '2014-07-30 20:49:43.756702',
        20
    );

UPDATE pre_order_item set reservation_id = (
    SELECT id FROM reservation WHERE
        ordering_id = 0 AND
        variant_id = 4310608 AND
        customer_id= 160 AND
        operator_id = ( select id from operator where name='Anastasija Grigorjeva') AND
        notified ='f' AND
        status_id=( select id from reservation_status where status='Pending') AND
        channel_id = ( select id from channel where  web_name ='NAP-APAC') AND
        reservation_source_id=20 AND
        id not in ( select reservation_id from pre_order_item where reservation_id is not null )
    )
    WHERE pre_order_id=770005904;


INSERT INTO pre_order_status_log ( pre_order_id,pre_order_status_id,operator_id,date ) VALUES (
    770005904,
    ( SELECT id FROM pre_order_status WHERE status = 'Complete' ),
    ( SELECT operator_id FROM pre_order WHERE id = 770005904 ),
    '2014-07-30 20:49:43.756702'
);

INSERT INTO pre_order_item_status_log ( pre_order_item_id, pre_order_item_status_id, operator_id, date ) VALUES (
    ( SELECT id FROM pre_order_item WHERE pre_order_id = 770005904 ),
    ( SELECT id FROM pre_order_item_status WHERE status = 'Complete' ),
    ( SELECT operator_id FROM pre_order WHERE id = 770005904 ),
    '2014-07-30 20:49:43.756702'
);


COMMIT WORK;
