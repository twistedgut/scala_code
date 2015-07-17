-- CANDO-577: Ading RMA Create Return email templates

BEGIN WORK;

-- Make sure the sequence table is updates
select setval('public.correspondence_templates_id_seq',(select max(id) from public.correspondence_templates));

-- RMA - Create Return template

-- For NAP
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
   'RMA - Create Return - NAP',
'Dear [% branded_salutation %],

[% IF refund_items.size %]
[% IF email_type == ''faulty'' %]
We''re sorry that your purchase has not met your expectations. Please could you return [% refund_items.size > 1 ? ''these items'' : ''this item'' %] to us so we can assess [% refund_items.size > 1 ? ''their'' : ''its'' %] condition and let you know the outcome.
[% ELSE %]
Thank you for your refund request for the following [% refund_items.size > 1 ? ''items'' : ''item'' %]:
[% END %]

[% FOREACH item_id = refund_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]
[% SET channel_brand_name  = ''NET-A-PORTER''; %]
[% IF renumerations.size != 0;
    IF renumerations.size == 1;

        # work out if BOTH Tax & Duties have been Refunded, so a message can be shown
        SET refunded_tax_and_duty_msg   = "";
        SET refunded_tax_and_duty       = 0;
        FOREACH ritem IN renumerations.0.renumeration_items;
            IF ritem.tax > 0 && ritem.duty > 0;
                refunded_tax_and_duty   = 1;
            END;
        END;
        IF refunded_tax_and_duty == 1;
            refunded_tax_and_duty_msg   = " This amount will include the taxes and duties paid when the order was placed.";
        END;

        IF renumerations.0.is_card_refund %]

As soon as we receive and process your return, we will credit [% renumerations.0.grand_total %] [% renumerations.0.currency.currency %] to your card.[% refunded_tax_and_duty_msg +%]
[%   ELSE %]

As soon as we receive and process your return, we will credit [% renumerations.0.grand_total %] [% renumerations.0.currency.currency %] as store credit to your [% channel_brand_name %] account.[% refunded_tax_and_duty_msg +%]
[%   END;
   ELSE %]

As soon as we receive and process your return, we will refund:

[%   FOREACH renumeration IN renumerations;
       IF renumeration.is_card_refund %]
- [% renumeration.grand_total | format(''%.2f'') %] [% renumeration.currency.currency %] to your card
[%     ELSIF renumeration.is_store_credit %]
- [% renumeration.grand_total | format(''%.2f'') %] [% renumeration.currency.currency %] as store credit to your [% channel_brand_name %] account
[%     END;
     END %]
[% END %]
[% END %]
[%  END # Refund items %]
[% IF exchange_items.size %][% IF email_type == ''faulty'' %]We''re sorry that your purchase has not met your expectations. Please could you return [% refund_items.size > 1 ? ''these items'' : ''this item'' %] to us so we can assess [% refund_items.size > 1 ? ''their'' : ''its'' %] condition and let you know the outcome.  [% ELSE %]Thank you for your exchange request for the following [% exchange_items.size > 1 ? ''items'' : ''item'' %]:
[% END %]

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% shipment_items.${ex.id}.designer_size +%]
[% END %]

[% IF email_type == ''faulty'' %]
In the meantime, the below [% exchange_items.size > 1 ? ''are'' : ''is'' %] reserved for you:
[% ELSIF ( ( charge_tax > 0 || charge_duty > 0 ) && can_set_debit_to_pending ) %]
As soon as we receive and process your return, we will dispatch your replacement [% exchange_items.size > 1 ? ''items'' : ''item'' %] below and debit [% charge_tax + charge_duty %] [% order.currency %] from the credit card used to place the order. If you would prefer to use an alternative credit card please let us know.
[% ELSE %]
As soon as we receive and process your return, we''ll dispatch the below [% exchange_items.size > 1 ? ''items'' : ''item'' %] to you:
[% END %]

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% ex.exchange_size +%]
[% END %]

[%-   IF ( ( charge_tax > 0 || charge_duty > 0 ) && !can_set_debit_to_pending ) %]

Your replacement item will incur additional customs duties imposed by your shipping destination. The total amount will be [% charge_tax + charge_duty %] [% order.currency %]


Please confirm that you are happy for us to debit this amount from the credit card used to place the order. If you would prefer to use an alternative credit card please let us know. Once we have processed this charge and received your return, we will then dispatch your exchange.

[%-   END; #IF DEBIT FOR EXCHANGE
   END #IF ITEMS BEING EXCHANGED %]

[% IF email_type == "late_credit_only" %]As stated in our returns policy, you should notify us of your wish to return within
[% return_cutoff_days %]
 days of receiving your order.  Given the lapse of time since you originally made this purchase, we are only able to refund it as a NET-A-PORTER store credit.

[% END %]Your returns number (RMA) is [% rma_number %].

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
   'RMA - Create Return - OUTNET',
'Dear [% branded_salutation %],

[% IF refund_items.size %]
[% IF email_type == ''faulty'' %]
We''re sorry that your purchase has not met your expectations. Please could you return [% refund_items.size > 1 ? ''these items'' : ''this item'' %] to us so we can assess [% refund_items.size > 1 ? ''their'' : ''its'' %] condition and let you know the outcome.
[% ELSE %]
We''ve received your refund request for the following [% refund_items.size > 1 ? ''items'' : ''item'' %]:
[% END %]

[% FOREACH item_id = refund_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]
[% SET  channel_brand_name  = ''THE OUTNET''; %]
[% IF renumerations.size != 0;
    IF renumerations.size == 1;

        # work out if BOTH Tax & Duties have been Refunded, so a message can be shown
        SET refunded_tax_and_duty_msg   = "";
        SET refunded_tax_and_duty       = 0;
        FOREACH ritem IN renumerations.0.renumeration_items;
            IF ritem.tax > 0 && ritem.duty > 0;
                refunded_tax_and_duty   = 1;
            END;
        END;
        IF refunded_tax_and_duty == 1;
            refunded_tax_and_duty_msg   = " This amount will include the taxes and duties paid when the order was placed.";
        END;

        IF renumerations.0.is_card_refund %]

As soon as we receive and process your return, we will credit [% renumerations.0.grand_total %] [% renumerations.0.currency.currency %] to your card.[% refunded_tax_and_duty_msg +%]
[%   ELSE %]

As soon as we receive and process your return, we will credit [% renumerations.0.grand_total %] [% renumerations.0.currency.currency %] as store credit to your [% channel_brand_name %] account.[% refunded_tax_and_duty_msg +%]
[%   END;
   ELSE %]

As soon as we receive and process your return, we will refund:

[%   FOREACH renumeration IN renumerations;
      IF renumeration.is_card_refund %]
- [% renumeration.grand_total | format(''%.2f'') %] [% renumeration.currency.currency %] to your card
[%     ELSIF renumeration.is_store_credit %]
- [% renumeration.grand_total | format(''%.2f'') %] [% renumeration.currency.currency %] as store credit to your [% channel_brand_name %] account
[%     END;
     END %]
[% END %]
[% END %]
[%  END # Refund items %]
[% IF exchange_items.size %][% IF email_type == ''faulty'' %]We''re sorry that your purchase has not met your expectations. Please could you return [% refund_items.size > 1 ? ''these items'' : ''this item'' %] to us so we can assess [% refund_items.size > 1 ? ''their'' : ''its'' %] condition and let you know the outcome.  [% ELSE %]We''ve received your exchange request for the following [% exchange_items.size > 1 ? ''items'' : ''item'' %]:
[% END %]

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% shipment_items.${ex.id}.designer_size +%]
[% END %]

[% IF email_type == ''faulty'' %]
In the meantime, the below [% exchange_items.size > 1 ? ''are'' : ''is'' %] reserved for you:
[% ELSIF ( ( charge_tax > 0 || charge_duty > 0 ) && can_set_debit_to_pending ) %]
As soon as we receive and process your return, we will dispatch your replacement [% exchange_items.size > 1 ? ''items'' : ''item'' %] below and debit [% charge_tax + charge_duty %] [% order.currency %] from the credit card used to place the order. If you would prefer to use an alternative credit card please let us know.
[% ELSE %]
As soon as we receive and process your return, we''ll dispatch the below [% exchange_items.size > 1 ? ''items'' : ''item'' %] to you:
[% END %]

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% ex.exchange_size +%]
[% END;

   END; #IF ITEMS BEING EXCHANGED

IF email_type;
   # This IF/ELSIF block was not in the original template on the confluence
   # page, it was added when we realised that the return creation pages in XT
   # had a drop down for different types of emails

IF email_type == "late_credit_only" %]

As stated in our returns policy, you should notify us of your wish to return within
[% return_cutoff_days %] days of receiving your order.  Given the lapse of time since you originally made this purchase, we are only able to refund it as a THE OUTNET store credit.
[%
   END;

END
%]

Your returns number (RMA) is [% rma_number %].

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
   'RMA - Create Return - MRP',
'Dear [% branded_salutation %],

[% IF refund_items.size %]
[% IF email_type == ''faulty'' %]
We are sorry that your purchase has not met your expectations. Please could you return [% refund_items.size > 1 ? ''these items'' : ''this item'' %] to us so we can assess [% refund_items.size > 1 ? ''their'' : ''its'' %] condition and let you know the outcome.
[% ELSE %]
Thank you for your refund request for the following [% refund_items.size > 1 ? ''items'' : ''item'' %]:
[% END %]

[% FOREACH item_id = refund_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]
[% SET  channel_brand_name  = ''MR PORTER''; %]
[% IF renumerations.size != 0;
    IF renumerations.size == 1;

        # work out if BOTH Tax & Duties have been Refunded, so a message can be shown
        SET refunded_tax_and_duty_msg   = "";
        SET refunded_tax_and_duty       = 0;
        FOREACH ritem IN renumerations.0.renumeration_items;
            IF ritem.tax > 0 && ritem.duty > 0;
                refunded_tax_and_duty   = 1;
            END;
        END;
        IF refunded_tax_and_duty == 1;
            refunded_tax_and_duty_msg   = " This amount will include the taxes and duties paid when the order was placed.";
        END;

        IF renumerations.0.is_card_refund %]

As soon as we receive and process your return, we will credit [% renumerations.0.grand_total %] [% renumerations.0.currency.currency %] to your card.[% refunded_tax_and_duty_msg +%]
[%   ELSE %]

As soon as we receive and process your return, we will credit [% renumerations.0.grand_total %] [% renumerations.0.currency.currency %] as store credit to your [% channel_brand_name %] account.[% refunded_tax_and_duty_msg +%]
[%   END;
   ELSE %]

As soon as we receive and process your return, we will refund:

[%   FOREACH renumeration IN renumerations;
       IF renumeration.is_card_refund %]
- [% renumeration.grand_total | format(''%.2f'') %] [% renumeration.currency.currency %] to your card
[%     ELSIF renumeration.is_store_credit %]
- [% renumeration.grand_total | format(''%.2f'') %] [% renumeration.currency.currency %] as store credit to your [% channel_brand_name %] account
[%     END;
     END %]
[% END %]
[% END %]
[%  END # Refund items %]
[% IF exchange_items.size %][% IF email_type == ''faulty'' %]We are sorry that your purchase has not met your expectations. Please could you return [% refund_items.size > 1 ? ''these items'' : ''this item'' %] to us so we can assess [% refund_items.size > 1 ? ''their'' : ''its'' %] condition and let you know the outcome.  [% ELSE %]Thank you for your exchange request for the following [% exchange_items.size > 1 ? ''items'' : ''item'' %]:
[% END %]

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% shipment_items.${ex.id}.designer_size +%]
[% END %]

[% IF email_type == ''faulty'' %]
In the meantime, the below [% exchange_items.size > 1 ? ''are'' : ''is'' %] reserved for you:
[% ELSIF ( ( charge_tax > 0 || charge_duty > 0 ) && can_set_debit_to_pending ) %]
As soon as we receive and process your return, we will dispatch your replacement [% exchange_items.size > 1 ? ''items'' : ''item'' %] below and debit [% charge_tax + charge_duty %] [% order.currency %] from the credit card used to place the order. If you would prefer to use an alternative credit card please let us know.
[% ELSE %]
As soon as we receive and process your return, we will dispatch the below [% exchange_items.size > 1 ? ''items'' : ''item'' %] to you:
[% END %]

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% ex.exchange_size +%]
[% END %]

[%-   IF ( ( charge_tax > 0 || charge_duty > 0 ) && !can_set_debit_to_pending ) %]

Your replacement item will incur additional customs duties imposed by your shipping destination. The total amount will be [% charge_tax + charge_duty %] [% order.currency %]


Please confirm that you are happy for us to debit this amount from the credit card used to place the order. If you would prefer to use an alternative credit card please let us know. Once we have processed this charge and received your return, we will then dispatch your exchange.

[%-   END; #IF DEBIT FOR EXCHANGE
   END #IF ITEMS BEING EXCHANGED %]

[% IF email_type == "late_credit_only" %]As stated in our returns policy, you should notify us of your wish to return within [% return_cutoff_days %] days of receiving your order.  Given the lapse of time since you originally made this purchase, we are only able to refund it as a MR PORTER store credit.

[% END %]Your returns number (RMA) is [% rma_number %].

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
   'RMA - Create Return - JC',
'Dear [% branded_salutation %],

[% IF refund_items.size %]
[% IF email_type == ''faulty'' %]
We''re sorry that your purchase has not met your expectations. Please could you return [% refund_items.size > 1 ? ''these items'' : ''this item'' %] to us so we can assess [% refund_items.size > 1 ? ''their'' : ''its'' %] condition and let you know the outcome.
[% ELSE %]
Thank you for your refund request for the following [% refund_items.size > 1 ? ''items'' : ''item'' %]:
[% END %]

[% FOREACH item_id = refund_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]
[% SET channel_brand_name  = ''JIMMY CHOO''; %]
[% IF renumerations.size != 0;
    IF renumerations.size == 1;

        # work out if BOTH Tax & Duties have been Refunded, so a message can be shown
        SET refunded_tax_and_duty_msg   = "";
        SET refunded_tax_and_duty       = 0;
        FOREACH ritem IN renumerations.0.renumeration_items;
            IF ritem.tax > 0 && ritem.duty > 0;
                refunded_tax_and_duty   = 1;
            END;
        END;
        IF refunded_tax_and_duty == 1;
            refunded_tax_and_duty_msg   = " This amount will include the taxes and duties paid when the order was placed.";
        END;

        IF renumerations.0.is_card_refund %]

As soon as we receive and process your return, we will credit [% renumerations.0.grand_total %] [% renumerations.0.currency.currency %] to your card.[% refunded_tax_and_duty_msg +%]
[%   ELSE %]

As soon as we receive and process your return, we will credit [% renumerations.0.grand_total %] [% renumerations.0.currency.currency %] as store credit to your [% channel_brand_name %] account.[% refunded_tax_and_duty_msg +%]
[%   END;
   ELSE %]

As soon as we receive and process your return, we will refund:

[%   FOREACH renumeration IN renumerations;
       IF renumeration.is_card_refund %]
- [% renumeration.grand_total | format(''%.2f'') %] [% renumeration.currency.currency %] to your card
[%     ELSIF renumeration.is_store_credit %]
- [% renumeration.grand_total | format(''%.2f'') %] [% renumeration.currency.currency %] as store credit to your [% channel_brand_name %] account
[%     END;
     END %]
[% END %]
[% END %]
[% END # Refund items %]
[% IF exchange_items.size %][% IF email_type == ''faulty'' %]We''re sorry that your purchase has not met your expectations. Please could you return [% refund_items.size > 1 ? ''these items'' : ''this item'' %] to us so we can assess [% refund_items.size > 1 ? ''their'' : ''its'' %] condition and let you know the outcome.  [% ELSE %]Thank you for your exchange request for the following [% exchange_items.size > 1 ? ''items'' : ''item'' %]:
[% END %]

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% shipment_items.${ex.id}.designer_size +%]
[% END %]

[% IF email_type == ''faulty'' %]
In the meantime, the below [% exchange_items.size > 1 ? ''are'' : ''is'' %] reserved for you:
[% ELSE %]
As soon we receive and process your return, we''ll dispatch the below [% exchange_items.size > 1 ? ''items'' : ''item'' %] to you:
[% END %]

[% FOREACH ex = exchange_items %]
- [% shipment_items.${ex.id}.designer %] [% shipment_items.${ex.id}.name %] - size [% ex.exchange_size +%]
[% END %]

[%-   IF charge_tax > 0 || charge_duty > 0 %]

Your replacement item will incur additional customs duties imposed by your shipping destination. The total amount will be [% charge_tax + charge_duty %] [% order.currency %]


Please confirm that you are happy for us to debit this amount from the credit card used to place the order. If you would prefer to use an alternative credit card please let us know. Once we have processed this charge and received your return, we will then dispatch your exchange.

[%-   END; #IF DEBIT FOR EXCHANGE
   END #IF ITEMS BEING EXCHANGED %]

[% IF email_type == "late_credit_only" %]As stated in our returns policy, you should notify us of your wish to return within
[% return_cutoff_days %]
 days of receiving your order.  Given the lapse of time since you originally made this purchase, we are only able to refund it as a JIMMY CHOO store credit.

[% END %]Your returns number (RMA) is [% rma_number %].

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
[% END # IF PREMIER %]');



COMMIT;
