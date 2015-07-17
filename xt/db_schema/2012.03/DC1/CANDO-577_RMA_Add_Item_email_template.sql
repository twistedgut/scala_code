-- CANDO-577: Ading RMA Add Item email templates

BEGIN WORK;

-- Make sure the sequence table is updates
select setval('public.correspondence_templates_id_seq',(select max(id) from public.correspondence_templates));

-- RMA - Add Item template

-- For NAP
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
   'RMA - Add Item - NAP',
'Dear [% branded_salutation %],

[%- IF exchange_items.size %]
Thank you for advising us that you also wish to exchange the following [% exchange_items.size > 1 ? ''items'' : ''item'' %] in addition to those previously requested on [% rma_number %]:

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% shipment_items.${ex.id}.designer_size +%]
[% END %]

As soon we receive and process your return, we''ll dispatch the below [% exchange_items.size > 1 ? ''items'' : ''item'' %] to you.

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% ex.exchange_size +%]
[% END;
   END #IF ITEMS BEING EXCHANGED %]

[% IF refund_items.size %]
Thank you for advising us that you also wish to return the [% refund_items.size > 1 ? ''items'' : ''item'' %] below in addition to those previously requested on [% rma_number %]:

[% FOREACH item_id = refund_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END;

   IF refund_type == ''card'' %]

As soon as we receive and process your return, we will refund your card. Please note card refunds may take up to ten business days for your bank to complete, depending on their processing time. This can vary greatly between card issuers and unfortunately we are unable to influence this.
[%   ELSIF refund_type == ''store_credit'' %]

As soon as we receive and process your return, we will issue your NET-A-PORTER store credit.
[% END #IF card refund/store credit %]

[% END; #IF ITEMS BEING REFUNDED %]
[% IF shipment.is_premier %]
Please sign the returns proforma invoice and include it with your return. This document was enclosed with your order when it was delivered. Our London Premier team will contact you within 48 hours to arrange a collection time.
[% ELSE %]
To send your return back to us, simply follow the below steps:

1. Book your free collection with DHL before your RMA number expires on [% return_expiry_date %]. To find the telephone number of your nearest DHL branch, visit www.dhl.com and select your country. Don''t forget to quote our account number, [% shipment.is_domestic ? ''135469417'' : ''961504478'' +%].
2. Sign [% IF shipment.shipment_address.is_eu_member_states %]a copy[% ELSE %]four copies[% END #IF EU %] of the returns proforma invoice to include with your return. These documents were enclosed with your order when it was delivered.
3. Complete and sign the DHL air waybill that was enclosed with your original order when it arrived. Please leave your package open until the driver has checked the contents.
[% END #IF PREMIER %]
[% UNLESS email_type == ''faulty'' %]

Please ensure that your returned items meet the conditions of our Returns Policy; http://www.net-a-porter.com/Help/ReturnsAndExchanges.
[% END %]

We''ll notify you by email once your return has been received and processed.  You can also track the status of this by referring to the My Orders page in My Account.

Please let us know if we can assist you further.

Kind regards,

[% IF shipment.is_premier %]
London Premier
www.net-a-porter.com

For assistance call 0800 044 5703 (8am - 9pm weekdays, 9am - 5pm weekends) or email [% channel_email_address.premier_email %]
[% ELSE %]
Customer Care
www.net-a-porter.com

For assistance [% channel_company_detail.contact_hours %], call UK 0800 044 5700 Rest of the world +44 (0)203 471 4510 or email [% channel_email_address.customercare_email %]
[% END # IF PREMIER %]');

-- For OUTNET
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
   'RMA - Add Item - OUTNET',
'Dear [% branded_salutation %],

[%- IF exchange_items.size %]
We''ve received your request to exchange the following [% exchange_items.size > 1 ? ''items'' : ''item'' %] as well as the ones you''ve already requested on [% rma_number %]:

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% shipment_items.${ex.id}.designer_size +%]
[% END %]

As soon we receive and process your return, we''ll dispatch the below item(s) to you.

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% ex.exchange_size +%]
[% END;
   END #IF ITEMS BEING EXCHANGED %]

[% IF refund_items.size %]
We''ve received your request to return the below [% refund_items.size > 1 ? ''items'' : ''item'' %] as well as the ones you''ve already requested on [% rma_number %]:

[% FOREACH item_id = refund_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END;

   IF refund_type == ''card'' %]

Once we''ve received and processed your return, we''ll refund your card. Please note card refunds may take up to ten business days for your bank to complete, depending on their processing time. This can vary greatly between card issuers and unfortunately we are unable to influence this.
[%   ELSIF refund_type == ''store_credit'' %]

Once we''ve received and processed your return, we''ll issue your THE OUTNET store credit right away so you can use it to snap up another irresistible bargain!
[% END; #IF card refund/store credit

   END; #IF ITEMS BEING REFUNDED %]
All you need to do now is send your returns back to us:

[% IF shipment.shipping_account.carrier.name == "DHL Ground" && shipment.return_airway_bill == "none" %]
1. A DHL customer service representative will be in touch within 48 hours to arrange a collection.
2. Sign [% IF shipment.shipment_address.is_eu_member_states %]a copy[% ELSE %]four copies[% END #IF EU %] of your proforma invoice to include with your return and leave the package open prior to collection. These documents were enclosed with your order when it was delivered.
3. If applicable, the courier will provide a return air waybill for completion at the point of collection.
[% ELSE %]
1. Book your collection with DHL before your RMA number expires on [% return_expiry_date %]. To find the telephone number of your nearest DHL branch, visit www.dhl.com and select your country.  Don''t forget to quote our account number, [% shipment.is_domestic ? ''182485224'' : ''950813062'' +%].
2. Sign [% IF shipment.shipment_address.is_eu_member_states %]a copy[% ELSE %]four copies[% END #IF DOMESTIC %] of the returns proforma invoice to include with your return. These documents were enclosed with your order when it was delivered.
3. Complete and sign the DHL air waybill enclosed with your original order. Please leave your package open until the driver has checked the contents.
[% END #IF %]
[% UNLESS email_type == ''faulty'' %]

For a speedy refund, please be sure that your returned items meet the conditions of our Returns Policy; http://www.theoutnet.com/Help/Returns-and-Exchanges
[% END %]

We''ll be in touch by email once we''ve received your returns.

Kind regards,

Customer Care
www.theoutnet.com

We''re here to help [% channel_company_detail.contact_hours %]! Call 0800 011 4250 from the UK, +44 (0)203 471 4777 from the rest of the world or email [% channel_email_address.customercare_email %]');    
-- For MRP

INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
   'RMA - Add Item - MRP',
'Dear [% branded_salutation %],

[%- IF exchange_items.size %]
Thank you for advising us that you also wish to exchange the following [% exchange_items.size > 1 ? ''items'' : ''item'' %] in addition to those previously requested on [% rma_number %]:

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% shipment_items.${ex.id}.designer_size +%]
[% END %]

As soon we receive and process your return, we''ll dispatch the below [% exchange_items.size > 1 ? ''items'' : ''item'' %] to you.

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% ex.exchange_size +%]
[% END;
   END #IF ITEMS BEING EXCHANGED %]

[% IF refund_items.size %]
Thank you for advising us that you also wish to return the below [% refund_items.size > 1 ? ''items'' : ''item'' %] in addition to those previously requested on [% rma_number %]:

[% FOREACH item_id = refund_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END;

   IF refund_type == ''card'' %]

As soon as we receive and process your return, we will refund your card. Please note card refunds may take up to ten business days for your bank to complete, depending on their processing time. This can vary greatly between card issuers and unfortunately we are unable to influence this.
[%   ELSIF refund_type == ''store_credit'' %]

As soon as we receive and process your return, we will issue your MR PORTER store credit.
[% END #IF card refund/store credit %]

[% END; #IF ITEMS BEING REFUNDED %]
[% IF shipment.is_premier %]
Please sign the returns proforma invoice and include it with your return. This document was enclosed with your order when it was delivered. Our London Premier team will contact you within 48 hours to arrange a collection time.
[% ELSE %]
To send your return back to us, simply follow the below steps:

1. Book your free collection with DHL before your RMA number expires on [% return_expiry_date %]. [% IF shipment.is_domestic %]Call 0844 248 0844 or visit http://www.dhl.com to find the telephone number of your nearest DHL branch[% ELSE %]To find the telephone number of your nearest DHL branch, visit http://www.dhl.com and select your country[% END %]. Remember to quote our account number, [%- IF shipment.is_domestic %]184385412[% ELSE -%]952110729[% END -%].

2. Sign [% IF shipment.shipment_address.is_eu_member_states %]a copy[% ELSE %]four copies[% END #IF EU %] of the returns proforma invoice to include with your return. These documents were enclosed with your order when it was delivered.

3. Complete and sign the DHL air waybill that was enclosed with your original order when it arrived. Please leave your package open until the driver has checked the contents.
[% END %]
[% UNLESS email_type == ''faulty'' %]

Please ensure that your returned items meet the conditions of our Returns Policy; http://www.mrporter.com/Help/ReturnsAndExchanges.
[% END %]

We will notify you by email once your return has been received and processed.  You can also track the status of this by referring to the My Orders page in My Account.

Please let us know if we can assist you further.

Yours sincerely,

[% IF shipment.is_premier %]
London Premier
http://www.mrporter.com

For assistance email [% channel_email_address.premier_email %] or call 0800 044 5708 from 8am-9pm weekdays and 9am-5pm weekends.
[% ELSE %]
Customer Care
http://www.mrporter.com

For assistance email [% channel_email_address.customercare_email %] or call 0800 044 5705 from the UK, +44(0)20 3471 4090 from the rest of the world, [% channel_company_detail.contact_hours %].

[% END %]');

-- For JC 
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
   'RMA - Add Item - JC', 
'Dear [% branded_salutation %],

[%- IF exchange_items.size %]
Thank you for advising us that you also wish to exchange the following [% exchange_items.size > 1 ? ''items'' : ''item'' %] in addition to those previously requested on [% rma_number %]:

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% shipment_items.${ex.id}.designer_size +%]
[% END %]

As soon we receive and process your return, we''ll dispatch the below [% exchange_items.size > 1 ? ''items'' : ''item'' %] to you.

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% ex.exchange_size +%]
[% END;
   END #IF ITEMS BEING EXCHANGED %]

[% IF refund_items.size %]
Thank you for advising us that you also wish to return the [% refund_items.size > 1 ? ''items'' : ''item'' %] below in addition to those previously requested on [% rma_number %]:

[% FOREACH item_id = refund_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END;

   IF refund_type == ''card'' %]

As soon as we receive and process your return, we will refund your card. Please note card refunds may take up to ten business days for your bank to complete, depending on their processing time. This can vary greatly between card issuers and unfortunately we are unable to influence this.
[%   ELSIF refund_type == ''store_credit'' %]

As soon as we receive and process your return, we will issue your JIMMY CHOO store credit.
[% END #IF card refund/store credit %]

[% END; #IF ITEMS BEING REFUNDED %]
[% IF shipment.is_premier %]
Please sign the returns proforma invoice and include it with your return. This document was enclosed with your order when it was delivered. Our London Premier team will contact you within 48 hours to arrange a collection time.
[% ELSE %]
To send your return back to us, simply follow the below steps:

1. Book your free collection with DHL before your RMA number expires on [% return_expiry_date %]. To find the telephone number of your nearest DHL branch, visit www.dhl.com and select your country. Don''t forget to quote our account number, [% shipment.is_domestic ? ''138916433'' : ''960063327'' +%].
2. Sign [% IF shipment.shipment_address.is_eu_member_states %]a copy[% ELSE %]four copies[% END #IF EU %] of the returns proforma invoice to include with your return. These documents were enclosed with your order when it was delivered.
3. Complete and sign the DHL air waybill that was enclosed with your original order when it arrived. Please leave your package open until the driver has checked the contents.
[% END #IF PREMIER %]

Items should be returned new, unused and in their original packaging with all JIMMY CHOO tags still attached. Please be aware that the shoe box is considered part of the product and the same terms apply. For more information, please refer to our legal terms.

We''ll notify you by email once your return has been received and processed.

Please let us know if we can assist you further.

Best wishes,

[% IF shipment.is_premier %]
London Premier Team
www.jimmychoo.com

For assistance call 0800 044 3221 (8am - 9pm weekdays, 9am - 5pm weekends) or email [% channel_email_address.premier_email %]
[% ELSE %]
Customer Care Team
www.jimmychoo.com

For assistance [% channel_company_detail.contact_hours %], call UK 0800 044 3221 Rest of the world +44 (0)20 3471 4799 or email [% channel_email_address.customercare_email %]
[% END # IF PREMIER %]');








COMMIT;