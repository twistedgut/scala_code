BEGIN;

UPDATE correspondence_templates SET content = E'
[% IF channel.business == ''NET-A-PORTER.COM'' %]Order number: [% IF order_info.order_nr %][% order_info.order_nr %][% ELSE %][% order.order_nr %][% END %]\r
\r
Dear [% invoice_address.first_name %],\r
\r
Your order has now been shipped and your [% shipment_row.shipping_account.carrier_name %] tracking number is [% shipment.outward_airway_bill %].\r
\r
Using this number you can track your package on our site www.net-a-porter.com. Simply ''SIGN IN'', select ''MY ACCOUNT'' followed by ''ORDER STATUS''. If you have shopped but not registered with us, click ''SIGN IN'',  select ''REGISTER NOW'' and complete your details to enable you to view the progress of your order, and when you can expect to receive it.\r
\r
IMPORTANT INFORMATION:\r
  - [% shipment_row.shipping_account.carrier_name %] will deliver your order between 9am to 5pm EST, Monday to Friday. If you are unavailable, [% shipment_row.shipping_account.carrier_name %] will leave a card so you can contact them to reschedule\r
  - All orders must be signed for upon delivery\r
  - Please note, we are unable to change the shipping address on your order now it is dispatched\r
  - Your purchase should arrive in perfect condition. If you are unhappy with the quality, please let us know immediately\r
  - Items should be returned new, unused, and with all NET-A-PORTER and designer garment tags still attached. In addition, shoes should be returned without scratches or stains and in their original, undamaged shoe box as this is considered part of the product\r
\r
Thank you for shopping at NET-A-PORTER.COM.\r
\r
Enjoy your fabulous new purchase!\r
\r
Best regards,\r
\r
Customer Care\r
www.net-a-porter.com\r
\r
For assistance 24 hours a day, seven days a week, call 1-800-481-1064 or email [% customercare_email %]\r
\r
[% ELSIF channel.business == ''theOutnet.com'' %]Order number: [% IF order_info.order_nr %][% order_info.order_nr %][% ELSE %][% order.order_nr %][% END %]\r
\r
Dear [% invoice_address.first_name %],\r
\r
Your order has now been shipped and your [% shipment_row.shipping_account.carrier_name %] tracking number is [% shipment.outward_airway_bill %]. \r
\r
Using this number you can track your package on our site www.theOutnet.com. Simply SIGN IN, select MY ACCOUNT followed by MY ORDERS. If you have shopped but not registered with us, click on ''SIGN IN'' and complete your details under ''REGISTER NOW'' to see the status of your order.\r
\r
IMPORTANT INFORMATION\r
\r
- [% shipment_row.shipping_account.carrier_name %] will deliver your order between 9am to 5pm EST, Monday to Friday. If you are unavailable, [% shipment_row.shipping_account.carrier_name %] will leave a card so  you can re-schedule this\r
- All orders must be signed for upon delivery\r
- We''re unable to redirect packages once they''re on their way\r
- Your purchase should arrive in perfect condition. If you''re unhappy with the quality, please let us know immediately\r
- Take extra care when trying on garments as we are unable to accept or exchange any returned items that are damaged or where the returns tag has been removed. Shoes should be returned without scratches or marks and in their original, undamaged box as this is considered part of the product\r
\r
Thank you for shopping at theOutnet.\r
\r
For more irresistible designer bargains, visit us weekly! \r
\r
Sincerely\r
\r
The Service Team        \r
www.theOutnet.com\r
\r
We''re here to help you seven days a week! Call 1-866-785-8246 (8am - 8pm EST weekdays, 9am - 5:30pm EST weekends) or email serviceteam.usa@theoutnet.com\r
\r
[% END %]
'
WHERE
    id = 18 AND name = 'Dispatch Order';

COMMIT;
