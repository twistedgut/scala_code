-- CANDO-2742: 'Special Order Upload Notification - Customer Care' Email
--             'Special Order Purchase Notification' Email
--             'Special Order Upload Notification' Email
--             'Reservation Notification - Product Advisors' Email
--             'Reservation Notification' Email

BEGIN WORK;

--
-- Special Order Upload Notification - Customer Care
--
UPDATE correspondence_templates
    SET subject         = 'Your reservation is now available'
WHERE   name LIKE 'Special Order Upload Notification - CC-NAP%'
OR      name LIKE 'Special Order Upload Notification - CC-OUTNET%'
;
UPDATE correspondence_templates
    SET subject         = 'Your Mr Porter reservation'
WHERE   name LIKE 'Special Order Upload Notification - CC-MRP%'
;

--
-- Special Order Upload Notification
--
UPDATE correspondence_templates
    SET subject         = 'Your reservation is now available'
WHERE   name LIKE 'Special Order Upload Notification-NAP%'
OR      name LIKE 'Special Order Upload Notification-OUTNET%'
;
UPDATE correspondence_templates
    SET subject         = 'Your Mr Porter reservation'
WHERE   name LIKE 'Special Order Upload Notification-MRP%'
;

--
-- Special Order Purchase Notification
--
UPDATE correspondence_templates
    SET subject         = 'Your Special Order Notification'
WHERE   name LIKE 'Special Order Purchase Notification-NAP%'
OR      name LIKE 'Special Order Purchase Notification-OUTNET%'
;
UPDATE correspondence_templates
    SET subject         = 'Your Mr Porter reservation'
WHERE   name LIKE 'Special Order Purchase Notification-MRP%'
;

--
-- Reservation Notification - Product Advisors
--
UPDATE  correspondence_templates
SET     subject     = 'Your Special Order'
WHERE   name        LIKE 'Reservation Notification - Product Advisors-NAP%'
;

UPDATE correspondence_templates
SET     subject     = 'Your Special Order'
WHERE   name        LIKE 'Reservation Notification - Product Advisors-OUTNET%'
;


--
-- Reservation Notification
--
UPDATE correspondence_templates
SET     subject     = 'Your Special Order'
WHERE   name        LIKE 'Reservation Notification-NAP%'
;

UPDATE correspondence_templates
SET     subject     = 'Your Special Order'
WHERE   name        LIKE 'Reservation Notification-OUTNET%'
;

UPDATE correspondence_templates
SET     subject     = 'Your MR PORTER reservation'
WHERE   name        LIKE 'Reservation Notification-MRP%'
;

COMMIT WORK;
