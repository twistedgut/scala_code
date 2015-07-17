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
[% SET channel_brand_name  = ''THE OUTNET''; %]
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
[% SET channel_brand_name  = ''MR PORTER''; %]
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
