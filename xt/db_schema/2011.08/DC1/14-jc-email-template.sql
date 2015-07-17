BEGIN;

-- add JC block to end of Dispatch email

UPDATE correspondence_templates  
SET content = REPLACE(content, 'For assistance email customercare@mrporter.com or call 0800 044 5705 from the UK, +44 (0)20 3471 4090 from the rest of the world, 24 hours a day, seven days a week', 
'For assistance email customercare@mrporter.com or call 0800 044 5705 from the UK, +44 (0)20 3471 4090 from the rest of the world, 24 hours a day, seven days a week

[% ELSIF channel.business == \'JIMMYCHOO.COM\' %]Order number: [% IF order_info.order_nr %][% order_info.order_nr %][% ELSE %][% order.order_nr %][% END %]

Dear [% invoice_address.first_name %],

Your order has now been shipped and your DHL Airway bill number is [% shipment.outward_airway_bill %]

Using this number you can track your package on the DHL website, http://www.dhl.com. 

Please be aware that, while your shipment has been processed and dispatched, it will take several hours before your number will register on the DHL website.

You will be able to view the progress for all future orders by signing into the JIMMY CHOO website and selecting View order history.

If you have any questions about your order that are not answered on our website, please email customercare@jimmychooonline.com.

Best wishes, 

Customer Care Team
www.jimmychoo.com
')
WHERE name = 'Dispatch Order';


-- credit/debit completed template

UPDATE correspondence_templates  
SET content = REPLACE(content, 'For assistance email customercare@mrporter.com or call 0800 044 5705 from the UK, +44 (0)20 3471 4090 from the rest of the world, 24 hours a day, seven days a week', 
'For assistance email customercare@mrporter.com or call 0800 044 5705 from the UK, +44 (0)20 3471 4090 from the rest of the world, 24 hours a day, seven days a week

[% ELSIF channel.business == \'JIMMYCHOO.COM\' %]Order number: [% invoice.order_nr %]

Dear [% invoice_address.first_name %],

[% IF invoice.renumeration_type_id == 1 %][% IF invoice.renumeration_class_id == 3 && invoice_items %]A refund for the following item[% IF invoice_items.defined AND invoice_items.size > 1 %]s[% END %] has now been issued as store credit to your JIMMY CHOO account. You can use [% invoice.total %] [% invoice.currency %] towards your next purchase within 12 months. 

[% FOREACH id = invoice_items.keys %] - [% invoice_items.$id.designer %] [% invoice_items.$id.name %]
[% END %][% ELSE %]We have now issued you with [% invoice.total %] [% invoice.currency %] of store credit.
[% END %]
To spend your store credit, simply log onto JIMMY CHOO and SIGN IN.

Once you have items in your Basket and you continue through to the Order Information page, the credit will be displayed as being automatically deducted from your purchase.
[% ELSIF invoice.renumeration_type_id == 2 %][% IF invoice.renumeration_class_id == 3 && invoice_items %]Thank you for returning the item[% IF invoice_items.defined AND invoice_items.size > 1 %]s[% END %] below.

[% FOREACH id = invoice_items.keys %] - [% invoice_items.$id.designer %] [% invoice_items.$id.name %]
[% END %]
[% END %]Your refund of [% invoice.total %] [% invoice.currency %] has now been issued to the original credit card used. 

Please note: card refunds may take up to 10 business days for your bank to complete, depending on their processing time. This can vary greatly between card issuers, and unfortunately we are unable to influence this.
[% IF invoice.renumeration_class_id == 3 %]
If you have returned other items from this order, they may still be processing. We\'ll email you once this is complete. 
[% END %][% ELSIF invoice.renumeration_type_id == 3 %]We have authorized our credit card agency to charge the following amount to your card: [% invoice.total %] [% invoice.currency %]
[% END %]
Thank you for shopping at JIMMYCHOO.COM. 

We hope you will shop again with us soon. 

Best wishes,

Customer Care Team
www.jimmychoo.com
')
WHERE name = 'Credit/Debit Completed';


-- Return Received template

UPDATE correspondence_templates  
SET content = REPLACE(content, 'For assistance email customercare@mrporter.com or call 0800 044 5705 from the UK, +44 (0)20 3471 4090 from the rest of the world, 24 hours a day, seven days a week',
'For assistance email customercare@mrporter.com or call 0800 044 5705 from the UK, +44 (0)20 3471 4090 from the rest of the world, 24 hours a day, seven days a week

[% ELSIF channel.business == \'JIMMYCHOO.COM\' %]Order number: [% order.order_nr %]

Dear [% shipping_address.first_name %],

Thank you for returning the following item[% IF returned.defined AND returned.size > 1 %]s[% END %]:
[% FOREACH item_id = returned.keys %][% SET ship_item_id = item_info.$item_id.shipment_item_id %]
 - [% shipment_item.$ship_item_id.designer %] [% shipment_item.$ship_item_id.name %]  
[% END %][% IF notreturned.defined AND notreturned.size > 0 %]
The below [% IF notreturned.defined AND notreturned.size > 1 %]items are[% ELSE %]item is[% END %] still outstanding for returns from this order.  [% IF notreturned.defined AND notreturned.size > 1 %]They[% ELSE %]It[% END %] may still be processing and we\'ll email you once this is complete. 
[% FOREACH item_id = notreturned.keys %][% SET ship_item_id = item_info.$item_id.shipment_item_id %]
 - [% shipment_item.$ship_item_id.designer %] [% shipment_item.$ship_item_id.name %] 
[% END %]
If you are no longer returning the above, please let us know within 48 hours. 
[% ELSE %]
[% IF return.exchange_shipment_id.defined AND return.exchange_shipment_id  > 0 %][% IF waiting_debit == 1 %]Before we can dispatch your exchanged item[% IF returned.defined AND returned.size > 1 %]s[% END %], we wanted to remind you that this replacement will incur additional customs duties as imposed by your shipping destination. Please confirm if you wish to proceed with your exchange, and that you authorize us to deduct this amount from the original credit card used.  If you would prefer to use an alternative credit card just let us know.[% ELSE %]Once your return has been processed, we\'ll dispatch your exchanged item[% IF returned.defined AND returned.size > 1 %]s[% END %] to you.[% END %][% ELSE %][% IF refund_type_id == 1 || refund_type_id == 2 %]You have requested a [% IF refund_type_id == 1 %]store credit[% ELSE %]credit card[% END %] refund. We\'ll email you again once your returns have been processed.[% END %][% END %]
[% END %][% IF notreturned.defined AND notreturned.size > 0 || waiting_debit == 1 %]
We look forward to hearing from you.
[% END %]
Best wishes, 

Customer Care Team
www.jimmychoo.com
')
WHERE name = 'Return Received';

COMMIT;