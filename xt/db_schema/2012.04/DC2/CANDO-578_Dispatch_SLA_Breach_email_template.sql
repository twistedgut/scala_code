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
'Dear [% branded_salutation %],

We are sorry it is taking longer than usual to dispatch your order.

We know you will be anxious to receive your purchase(s) so we have upgraded your shipping method from UPS Ground to UPS Express as a complimentary gesture to speed up the delivery process and ensure that your item(s) arrive sooner.

As soon as your shipment is on its way to you, we will send you an email with your tracking number so you can follow its progress online.

In the meantime, thank you for your patience, and don’t hesitate to contact us if you have any questions.

Best regards,

Customer Care

For assistance [% contact_hours %], call +1 877 6789 NAP (627) or email [% customercare_email %]');



--For OUTNET
INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
    'Dispatch-SLA-Breach-OUTNET',
'Dear [% branded_salutation %],

We''re sorry it is taking longer than usual to dispatch your order.

We know you''ll be anxious to receive your fabulous find(s) so we''ve upgraded your shipping method from UPS Ground to UPS Express as a complimentary gesture, to speed up the delivery process and ensure that your item(s) arrive sooner.

As soon as your shipment is on its way to you, we will send you an email with your tracking number so you can follow its progress online.

In the meantime, thank you for your patience, and please don’t hesitate to contact us if you have any questions.

Best regards,

Customer Care

We''re here to help [% contact_hours %]! Call +1 888 9 OUTNET (688638), or email [% customercare_email %]');

--For MRP

INSERT INTO public.correspondence_templates (
    access,
    name,
    content
)
VALUES (
    0,
    'Dispatch-SLA-Breach-MRP',
'Dear [% branded_salutation %],

We are sorry it is taking longer than usual to dispatch your order. 

We know you will be anxious to receive your purchase(s) so we have upgraded your shipping method from UPS Ground to UPS Express as a complimentary gesture to speed up the delivery process and ensure that your item(s) arrive sooner.

As soon as your shipment is on its way to you, we will send you an email with your tracking number so you can follow its progress online.

In the meantime, thank you for your patience, and do not hesitate to contact us if you have any questions.

Yours sincerely,

Customer Care

For assistance [% contact_hours %], call +1 877 5353 677 or email [% customercare_email %]');

COMMIT;

