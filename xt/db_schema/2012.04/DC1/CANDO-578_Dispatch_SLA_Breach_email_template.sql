-- CANDO-578: Dispatch SLA Breach template

BEGIN WORK;

-- Make sure the sequence table is updates
select setval('public.correspondence_templates_id_seq',(select max(id) from public.correspondence_templates));


-- For NAP
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
    'Dispatch-SLA-Breach-NAP',
'Dear  [% branded_salutation %],

We are sorry it is taking longer than usual to dispatch your order.

We know you will be anxious to receive your purchase(s) so we have upgraded your shipping method from DHL European Standard to DHL European Express as a complimentary gesture to speed up the delivery process and ensure that your item(s) arrive sooner.

As soon as your shipment is on its way to you, we will send you an email with your air waybill number so you can track its progress online.

In the meantime, thank you for your patience, and don’t hesitate to contact us if you have any questions.

Kind regards,

Customer Care

For assistance [% contact_hours %], seven days a week, call 0800 044 5700 from the UK, +44 (0)20 3471 4510 internationally or email [% customercare_email %]');

--For OUTNET
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
    'Dispatch-SLA-Breach-OUTNET',
'Dear  [% branded_salutation %],

We''re sorry it is taking longer than usual to dispatch your order.

We know you''ll be anxious to receive your fabulous find(s) so we''ve upgraded your shipping method from DHL European Standard to DHL European Express as a complimentary gesture, to speed up the delivery process and ensure that your item(s) arrive sooner.

As soon as your shipment is on its way to you, we will send you an email with your air waybill number so you can track its progress online.
In the meantime, thank you for your patience, and please don’t hesitate to contact us if you have any questions.

Kind regards,

Customer Care

We''re here to help [% contact_hours %]! Call 0800 011 4250 from the UK, +44 (0)20 3471 4777 from the rest of the world, or email [% customercare_email %]');

--For MRP

INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
    'Dispatch-SLA-Breach-MRP',
'Dear  [% branded_salutation %],

We are sorry it is taking longer than usual to dispatch your order. 

We know you will be anxious to receive your purchase(s) so we have upgraded your shipping method from DHL European Standard to DHL European Express as a complimentary gesture to speed up the delivery process and ensure that your item(s) arrive sooner.

As soon as your shipment is on its way to you, we will send you an email with your air waybill number so you can track its progress online.

In the meantime, thank you for your patience, and do not hesitate to contact us if you have any questions.

Yours sincerely,

Customer Care

For assistance [% contact_hours %], call 0800 044 5705 from the UK, +44 (0)20 3471 4090 internationally or email [% customercare_email %]');

COMMIT;



