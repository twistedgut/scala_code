-- CANDO-2052, CANDO-2291: 'Request Price Change Confirmation' Email
--                         updates its 'correspondence_templates' record

BEGIN WORK;

UPDATE correspondence_templates
    SET subject         = 'Your order - [% order_number %]',
        id_for_cms      = 'TT_REQUEST_PRICE_CHANGE'
WHERE   name = 'Request Price Change Confirmation'
AND     id_for_cms IS NULL
;

COMMIT WORK;
