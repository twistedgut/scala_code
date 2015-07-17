-- Purpose:
-- Create new e-mail templates as part of the ongoing effort to remove nasty hardcoded things

BEGIN;

INSERT INTO correspondence_templates (id, access, name, content) VALUES(53, 0, 'Return Faulty', 
'Dear [% address_info.first_name %],

We are writing to confirm receipt of the following item:
		
 - [% item_designer %] [% item_name %]

Our Quality Control Department have inspected this item and have now confirmed that it has not met our high quality standards.

Please accept our sincerest apologies for any inconvenience caused by this situation.

Should you wish additional information regarding this return, please email us at returns.usa@net-a-porter.com.

[% IF is_exchange %]
Our Shipping Department will now arrange for the dispatch of your replacement item as soon as possible.
[% ELSIF is_store_credit %]
Our Finance Department will email you to confirm the NET-A-PORTER store credit available to you shortly.
[% ELSIF is_chargeback %]
Our Finance Department will email you shortly, once your full refund has been processed back on to your credit card.

Please be aware that your refund will be processed within two weeks as the credit card agencies can take up to 10 days to credit funds back onto your credit card.
[% END %]

Many thanks and kind regards,

Returns Department USA
www.net-a-porter.com


');


INSERT INTO correspondence_templates (id, access, name, content) VALUES(54, 0, 'Reservation Notification', 
'Dear [% customer.first_name %],

I hope you are well.

Just to let you know, that the below items from your seasonal wish list are due to be available to you this week:


[% FOREACH id = reservations.keys %][% SET var_id = reservations.$id.variant_id %][% IF reservations.$id.status_id == 1 && nextupload.$var_id == 1 %]
[% reservations.$id.designer %] [% reservations.$id.product_name %] Size: [% reservations.$id.designer_size %]

[% END %][% END %]

If you are still interested in purchasing the above, please do let me know and I will be happy to arrange the Special Orders on your account when the items go live.

Alternatively, if you would prefer me to charge and send the order out to you on your behalf, I can arrange this for you also.

I look forward to hearing from you.

Best wishes,


[% operator.first_name %]


Personal Shopper
www.net-a-porter.com

');
COMMIT;