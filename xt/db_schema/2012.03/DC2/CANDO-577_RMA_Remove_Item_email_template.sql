-- CANDO-577: Remove Item email templates

BEGIN WORK;

-- Make sure the sequence table is updates
select setval('public.correspondence_templates_id_seq',(select max(id) from public.correspondence_templates));

-- RMA - Remove item Return template

-- For NAP
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
   'RMA - Remove Item - NAP',
'Dear [% branded_salutation %],

Thank you for advising us that you wish to remove the following [% return_items.size > 1 ? ''items'' : ''item'' %] from [% return.rma_number %]:

[% FOREACH item_id = return_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]

As soon as we receive your remaining returns, we''ll process your refund/exchange.

[% IF shipment.is_premier %]
Please sign the returns proforma invoice and include it with your return. Our New York Premier team will contact you within 24 hours to arrange a collection time.
[% ELSE %]
To send your return back to us, simply follow the below steps:

[%   IF shipment.is_domestic %]
1. Book your free collection with UPS before your RMA number expires on [% return_expiry_date %] by calling 1800 823 7459 and quoting our account number X248F0. Alternatively drop your shipment off at your local UPS store or at any UPS facility.
2. Complete and sign a copy of the returns proforma invoice enclosed with your order and include it with your return.
3. Then attach the UPS label on the outside of the box and leave your package open until the driver has checked the contents.
[%   ELSE %]
1. Book your free collection with DHL before your RMA number expires on [% return_expiry_date %].  To find the telephone number of your nearest DHL branch, visit www.dhl.com and select your country. Don’t forget to quote our account number, 965306988.
2. Sign four copies of the returns proforma invoice and include them with your return. These documents were enclosed with your order when it was delivered.
3. Complete and sign the DHL air waybill that was enclosed with your original order when it arrived. Please leave your package open until the driver has checked the contents.
[%   END; # IF DOMESTIC
   END # IF PREMIER
%]
[% UNLESS email_type == ''faulty'' %]

Please ensure that your returned items meet the conditions of our Returns Policy; http://www.net-a-porter.com/am/Help/ReturnsAndExchanges.
[% END %]

We''ll notify you by email once your return has been received and processed.  You can also track the status of this by referring to the My Orders page in My Account.

Please let us know if we can assist you further.

We''d love to hear your feedback on shopping with NET-A-PORTER. Please click on the link to take part in our short survey http://www.snapsurveys.com/swh/surveylogin.asp?k=131556330957

Best regards,

[% IF shipment.is_premier %]
New York Premier
www.net-a-porter.com

For assistance call 1 877 5060 NYP (697) 8.30am-8pm weekdays, 9am-5.30pm weekends or email [% channel_email_address.premier_email %]
[% ELSE %]
Customer Care
www.net-a-porter.com

For assistance [% channel_company_detail.contact_hours %], call 1-800-481-1064 or email [% channel_email_address.customercare_email %]
[% END # IF PREMIER %]');

-- For OUTNET
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
   'RMA - Remove Item - OUTNET',
'Dear [% branded_salutation %],

We''re delighted you''ve decided to keep the following [% return_items.size > 1 ? ''items'' : ''item'' %] from [% return.rma_number %]:

[% FOREACH item_id = return_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]

Once we receive your remaining returns(s), we''ll process your refund/exchange.

All you need to do now is send your returns back to us:

[% IF shipment.is_domestic %]
1. Book your free collection with UPS before your RMA number expires on [% return_expiry_date %] by calling 1800 823 7459 and quoting our account number X2480W. Alternatively drop your shipment off at your local UPS store or at any UPS facility.
2. Complete and sign a copy of the returns proforma invoice enclosed with your order and include it with your return.
3. Then attach the UPS label on the outside of the box and leave your package open until the driver has checked the contents.
[% ELSE %]
1. Book your collection with DHL before your RMA number expires on [% return_expiry_date %]. To find the telephone number of your nearest DHL branch, visit www.dhl.com and select your country. Don’t forget to quote our account number, 965301248.
2. Sign four copies of the returns proforma invoice and include them with your return. These documents were enclosed with your order when it was delivered.
3. Complete and sign the DHL air waybill enclosed with your original order. Please leave your package open until the driver has checked the contents.
[% END #IF DOMESTIC %]
[% UNLESS email_type == ''faulty'' %]

For a speedy refund, please be sure that your returned items meet the conditions of our Returns Policy; http://www.theoutnet.com/am/Help/Returns-and-Exchanges
[% END %]

We''ll be in touch by email once we''ve received your returns.

Sincerely,

Customer Care
www.theoutnet.com

We''re here to help [% channel_company_detail.contact_hours %]! Call +1 888 9 OUTNET (688638) or email [% channel_email_address.customercare_email %]');

-- For MRP

INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
   'RMA - Remove Item - MRP',
'Dear [% branded_salutation %],

Thank you for advising us that you wish to remove the following [% return_items.size > 1 ? ''items'' : ''item'' %] from [% return.rma_number %]:

[% FOREACH item_id = return_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]

As soon as we receive your remaining returns, we will process your refund/exchange.

[% IF shipment.is_premier %]
Please sign the returns proforma invoice and include it with your return. Our New York Premier team will contact you within 24 hours to arrange a collection time.
[% ELSE %]
To send your return back to us, simply follow the below steps:

[%- IF shipment.is_domestic %]
1. Book your free collection with UPS before your RMA number expires on [% return_expiry_date %] by calling 1800 823 7459 and quoting our account number X27W90. Alternatively drop your shipment off at your local UPS store or at any UPS facility.
2. Complete and sign a copy of the returns proforma invoice enclosed with your order and include it with your return.
3. Then attach the UPS label on the outside of the box and leave your package open until the driver has checked the contents.
[%   ELSE %]
1. Book your free collection with DHL before your RMA number expires on [% return_expiry_date %].  To find the telephone number of your nearest DHL branch, visit http://www.dhl.com and select your country. Remember to quote our account number, 968511510.
2. Complete and sign four copies of the returns proforma invoice that you received with your order (and fill in the DHL air waybill if applicable)
3. Then leave your package open until the driver has checked the contents.
[%   END; # IF DOMESTIC
   END # IF PREMIER
%]
[% UNLESS email_type == ''faulty'' %]

Please ensure that your returned items meet the conditions of our Returns Policy; http://www.mrporter.com/am/Help/ReturnsAndExchanges.
[% END %]

We will notify you by email once your return has been received and processed.  You can also track the status of this by referring to the My Orders page in My Account.

Please let us know if we can assist you further.

Yours sincerely,

[% IF shipment.is_premier %]
New York Premier
http://www.mrporter.com

For assistance email [% channel_email_address.premier_email %] or call 1 877 93 NY MRP (69677) from 8.30am-8pm EST, on weekdays and 9am-5.30pm EST, on weekends.
[% ELSE %]
Customer Care
http://www.mrporter.com

For assistance email [% channel_email_address.customercare_email %] or call +1 877 5353 MRP (677) [% channel_company_detail.contact_hours %].
[% END # IF PREMIER %]');


-- For JC 
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
   'RMA - Remove Item - JC',
'Dear [% branded_salutation %],

Thank you for advising us that you wish to remove the following [% return_items.size > 1 ? ''items'' : ''item'' %] from [% return.rma_number %]:

[% FOREACH item_id = return_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]

As soon as we receive your remaining returns, we''ll process your refund/exchange.

[% IF shipment.is_premier %]
Please sign the returns proforma invoice and include it with your return. Our New York Premier team will contact you within 24 hours to arrange a collection time.
[% ELSE %]
To send your return back to us, simply follow the below steps:

[%   IF shipment.is_domestic %]
1.Book your free collection with UPS before your RMA number expires on [% return_expiry_date %] by calling 1800 823 7459. Alternatively drop your shipment off at your local UPS store or at any UPS facility.
2. Please give our account number X2477X and select the ''Second Day Air'' option. You will also need your tracking number which begins with ''1Z'' .
3. Complete and sign a copy of the returns proforma invoice enclosed with your order and include it with your return.
4. Then attach the UPS label on the outside of the box and leave your package open until the driver has checked the contents.
[%   ELSE %]
1. Book your free collection with DHL before your RMA number expires on [% return_expiry_date %].  To find the telephone number of your nearest DHL branch, visit www.dhl.com and select your country. Don’t forget to quote our account number, 969485023.
2. Sign four copies of the returns proforma invoice and include them with your return. These documents were enclosed with your order when it was delivered.
3. Complete and sign the DHL air waybill that was enclosed with your original order when it arrived. Please leave your package open until the driver has checked the contents.
[%   END; # IF DOMESTIC
   END # IF PREMIER
%]

Items should be returned new, unused and in their original packaging with all JIMMY CHOO tags still attached. Please be aware that the shoe box is considered part of the product and the same terms apply. For more information, please refer to our legal terms.

We''ll notify you by email once your return has been received and processed.

Please let us know if we can assist you further.

Best wishes,

[% IF shipment.is_premier %]
New York Premier Team
www.jimmychoo.com

For assistance call 1-877-539-2466 (8am - 9pm weekdays, 9am - 5pm weekends) or email [% channel_email_address.premier_email %]
[% ELSE %]
Customer Care Team
www.jimmychoo.com

For assistance [% channel_company_detail.contact_hours %], call 1-877-539-2466 or email [% channel_email_address.customercare_email %]
[% END # IF PREMIER %]
');



COMMIT;
