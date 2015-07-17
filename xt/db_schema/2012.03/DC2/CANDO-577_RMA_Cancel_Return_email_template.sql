-- CANDO-577: Ading RMA Cancel Return email templates

BEGIN WORK;

-- Make sure the sequence table is updates
select setval('public.correspondence_templates_id_seq',(select max(id) from public.correspondence_templates));

-- RMA - Cancel Return template

-- For NAP 
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
    'RMA - Cancel Return - NAP', 
'Dear [% branded_salutation %],

Thank you for letting us know that you no longer wish to return the below [% return_items.size == 1 ? ''item'' : ''items'' %] from your order:

[% FOREACH item_id = return_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]

We hope you enjoy your purchase and will shop again with us soon!

Best regards,

[%   IF shipment.is_premier %]
New York Premier
www.net-a-porter.com

For assistance call (347) 468-7979 (8.30am-8pm weekdays, 9am-5.30pm weekends) or email [% channel_email_address.premier_email %]
[%   ELSE %]
Customer Care
www.net-a-porter.com

For assistance [% channel_company_detail.contact_hours %], call 1-800-481-1064 or email [% channel_email_address.customercare_email %]
[%   END; # IF PREMIER %] ');


-- For MRP

INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
    'RMA - Cancel Return - MRP',
'Dear [% branded_salutation %],

Thank you for letting us know that you no longer wish to return the below [% return_items.size == 1 ? ''item'' : ''items'' %] from your order:

[% FOREACH item_id = return_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]

MR PORTER looks forward to welcoming you back soon.

Yours sincerely,

[%   IF shipment.is_premier %]
New York Premier
www.mrporter.com

For assistance email [% channel_email_address.premier_email %] or call 1 877 93 NY MRP (69677) from 8.30am-8pm EST, on weekdays and 9am-5.30pm EST, on weekends.
[%   ELSE %]
Customer Care
www.mrporter.com

For assistance email [% channel_email_address.customercare_email %] or call +1 877 5353 MRP (677) [% channel_company_detail.contact_hours %].
[%   END; # IF PREMIER %] ');

--For OUTNET

INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
    'RMA - Cancel Return - OUTNET',
'Dear [% branded_salutation %],

We''re delighted you''ve decided to keep your purchase from THE OUTNET!
As you''ve requested, we''ve cancelled your RMA number for the following [% return_items.size == 1 ? ''item'' : ''items'' %]:

[% FOREACH item_id = return_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]

Thank you for shopping at the most fashionable fashion outlet.

We hope you will come back and shop again soon from our dazzling selection of designer looks at chic-onomic prices.

Sincerely,

Customer Care
www.theoutnet.com

We''re here to help [% channel_company_detail.contact_hours %]! Call 1-888-9-OUTNET(688638) (8am - 8pm EST weekdays, 9am - 5.30pm EST weekends) or email [% channel_email_address.customercare_email %] ');

--For JC
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
) 
VALUES (
    0,
    'RMA - Cancel Return - JC',
'Dear [% branded_salutation %],

Thank you for letting us know that you no longer wish to return the below [% return_items.size == 1 ? ''item'' : ''items'' %] from your order:

[% FOREACH item_id = return_items %]
- [% shipment_items.${item_id}.designer %] [% shipment_items.${item_id}.name %] - size [% shipment_items.${item_id}.designer_size +%]
[% END %]

We hope you enjoy your purchase and will shop again with us soon!

Best wishes,

[%   IF shipment.is_premier %]
New York Premier Team
www.jimmychoo.com

For assistance call 1-877-539-2466 (8am - 9pm weekdays, 9am - 5pm weekends) or email [% channel_email_address.premier_email %]
[%   ELSE %]
Customer Care Team
www.jimmychoo.com

For assistance [% channel_company_detail.contact_hours %], call 1-877-539-2466 or email [% channel_email_address.customercare_email %]
[%   END; # IF PREMIER %] ');


COMMIT;
