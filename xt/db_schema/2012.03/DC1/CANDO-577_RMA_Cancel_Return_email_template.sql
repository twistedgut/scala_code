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

Kind regards,

[%   IF shipment.is_premier %]
London Premier
www.net-a-porter.com

For assistance call 0800 044 5703 (8am - 9pm weekdays, 9am - 5pm weekends) or email [% channel_email_address.premier_email %]
[%   ELSE %]
Customer Care
www.net-a-porter.com

For assistance [% channel_company_detail.contact_hours %], call UK 08456 75 13 21 Rest of the world +44 (0)1473 32 30 32 or email [% channel_email_address.customercare_email %]
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
London Premier
www.mrporter.com

For assistance email [% channel_email_address.premier_email %] or call 0800 044 5708 from 8am-9pm weekdays and 9am-5pm weekends.
[%   ELSE %]
Customer Care
www.mrporter.com

For assistance email [% channel_email_address.customercare_email %] or call 0800 044 5705 from the UK, +44(0)20 3471 4090 from the rest of the world, [% channel_company_detail.contact_hours %].
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

Kind regards,

Customer Care
www.theoutnet.com

We''re here to help [% channel_company_detail.contact_hours %]! Call UK 0844 857 0844 Rest of world +44 (0) 207 078 0505 (8am - 8pm GMT weekdays, 9am - 5.30pm GMT weekends) or email [% channel_email_address.customercare_email %]');

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
London Premier Team
www.jimmychoo.com

For assistance call 0800 044 3221 (8am - 9pm weekdays, 9am - 5pm weekends) or email [% channel_email_address.premier_email %]
[%   ELSE %]
Customer Care Team
www.jimmychoo.com

For assistance [% channel_company_detail.contact_hours %], call UK 0800 044 3221 Rest of the world +44 (0)20 3471 4799 or email [% channel_email_address.customercare_email %]
[%   END; # IF PREMIER %] ');


COMMIT;
