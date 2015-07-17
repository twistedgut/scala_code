-- CANDO-1282: Add Subject, Type, CMS Id, Read-Only flag
--             to 'correspondence_templates' table

BEGIN WORK;

ALTER TABLE correspondence_templates
    ADD COLUMN subject CHARACTER VARYING(255),
    ADD COLUMN content_type CHARACTER VARYING(10),
    ADD COLUMN readonly BOOLEAN DEFAULT FALSE NOT NULL,
    ADD COLUMN id_for_cms CHARACTER VARYING(255)
;

-- Populate some Subjects for the Top 10 Emails!
UPDATE correspondence_templates
    SET subject = 'Your order - [% order_number %]'
WHERE   name IN (
        'Dispatch Order',
        'Credit/Debit Completed',
        'Return Received',
        'DDU Order - Request accept shipping terms',
        'DDU Order - Follow Up'
    )
OR      name LIKE 'RMA - %'
;

-- update the 'content_type' to be text or html
UPDATE  correspondence_templates
    SET content_type    = 'text'        -- everything is 'text'
;

UPDATE  correspondence_templates
    SET content_type    = 'html'
WHERE   name IN (
        'Special Order Purchase Notification-MRP-AM',
        'Special Order Purchase Notification-NAP-AM',
        'Special Order Purchase Notification-OUTNET-AM',
        'Special Order Upload Notification - CC-MRP-AM',
        'Special Order Upload Notification - CC-NAP-AM',
        'Special Order Upload Notification - CC-OUTNET-AM',
        'Special Order Upload Notification-MRP-AM',
        'Special Order Upload Notification-NAP-AM',
        'Special Order Upload Notification-OUTNET-AM',
        'Special Order Purchase Notification-MRP-INTL',
        'Special Order Purchase Notification-NAP-INTL',
        'Special Order Purchase Notification-OUTNET-INTL',
        'Special Order Upload Notification - CC-MRP-INTL',
        'Special Order Upload Notification - CC-NAP-INTL',
        'Special Order Upload Notification - CC-OUTNET-INTL',
        'Special Order Upload Notification-MRP-INTL',
        'Special Order Upload Notification-NAP-INTL',
        'Special Order Upload Notification-OUTNET-INTL'
    )
;

ALTER TABLE correspondence_templates
    ALTER COLUMN content_type SET NOT NULL
;

COMMIT WORK;
