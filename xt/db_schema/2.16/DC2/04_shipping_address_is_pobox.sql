BEGIN;

UPDATE correspondence_templates SET content = E'
Dear [% invoice_address.first_name %],\r
\r
Thank you for shopping at [% channel.business %].\r
\r
Unfortunately, our carrier partner [% shipment_row.shipping_account.carrier_name %] is unable to ship to PO Box addresses due to shipping restrictions.\r
\r
Please provide us with an alternative address where our carrier service can obtain a signature upon delivery.\r
\r
Please be aware that any change in the shipping destination may require your order to undergo a routine security check which could potentially delay the delivery of your shipment.  \r
\r
Should you have any questions please do contact us.\r
\r
Kind regards,\r
\r
[% IF channel.business == ''theOutnet.com'' %]The [% END %][% channel.email_signoff %]\r
[% channel.url %]
'
WHERE
    id = 8
    AND name = 'Shipping Address is PO Box';

COMMIT;
