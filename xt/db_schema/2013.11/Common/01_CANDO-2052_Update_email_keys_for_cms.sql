BEGIN WORK;
-- CANDO-2052,2053 : Updating correspondence_templates table to have CMS Id's

UPDATE correspondence_templates  SET id_for_cms='TT_REFUND_CARD_EXPIRED' WHERE   name = 'Refund - Card Expired';
UPDATE correspondence_templates  SET id_for_cms='TT_REFUND_CARD_EXPIRED_CHASE_UP' WHERE   name = 'Refund - Card Expired - Chase up';
UPDATE correspondence_templates  SET id_for_cms='TT_REFUND_DECLINED_RESPONSE_CUSTOMER_CARE_EMAIL' WHERE   name = 'Refund - Declined response';
UPDATE correspondence_templates  SET id_for_cms='TT_REFUND_DECLINED_RESPONSE_CHASE_UP' WHERE   name = 'Refund - Declined response - Chase up';
UPDATE correspondence_templates  SET id_for_cms='TT_SHIPPING_ADDRESS_IS_AMAREX' WHERE   name = 'Shipping Address is Amarex';
UPDATE correspondence_templates  SET id_for_cms='TT_PO_BOX' WHERE   name = 'Shipping Address is PO Box';
UPDATE correspondence_templates  SET id_for_cms='TT_CONFIRM_CANCELLED_ITEM' WHERE name = 'Confirm Cancelled Item';
UPDATE correspondence_templates  SET id_for_cms='TT_CONFIRM_CANCELLED_ORDER' WHERE name='Confirm Cancelled Order';

--update subject and content_type
UPDATE  correspondence_templates
    SET subject = 'Your order - [% order_number %]'
WHERE   subject IS NULL
AND     name IN (
    'Refund - Card Expired',
    'Refund - Card Expired - Chase up',
    'Refund - Declined response',
    'Refund - Declined response - Chase up',
    'Shipping Address is Amarex',
    'Shipping Address is PO Box',
    'Confirm Cancelled Item',
    'Confirm Cancelled Order'

);

UPDATE correspondence_templates SET
 id_for_cms='TT_DISPATCH_SLA_BREACH', subject='[% brand_name %] order update - [% order_number %]'
WHERE name='Dispatch-SLA-Breach-NAP';
UPDATE correspondence_templates SET
 id_for_cms='TT_DISPATCH_SLA_BREACH', subject='[% brand_name %] order update - [% order_number %]'
WHERE name='Dispatch-SLA-Breach-OUTNET';
UPDATE correspondence_templates SET
 id_for_cms='TT_DISPATCH_SLA_BREACH', subject='[% brand_name %] order update - [% order_number %]'
WHERE name='Dispatch-SLA-Breach-MRP';

COMMIT WORK;

