-- CANDO-1889: Updates P2 & P3 Emails with Subjects

BEGIN WORK;

--
-- P2 Emails
--

UPDATE  correspondence_templates
    SET subject = 'Your order - [% order_number %]'
WHERE   name = 'DDU Order - Set Up Permanent DDU Terms And Conditions'
;

-- These Emails are sent via the 'Send Email' menu option
-- on the Order View page and all have the same Subject
UPDATE  correspondence_templates
    SET subject = 'Your order - [% order_number %]'
WHERE   subject IS NULL
AND     name IN (
    'Authorization code required',
    'Security Credit - Billing & shipping address different',
    'Security credit - cannot verify billing address',
    'Security Credit - Chase up',
    'Security Credit - Final Reminder',
    'Security Credit - Order of high value',
    'Security Credit - Wrong Amount Supplied',
    'Send order to billing address'
)
;

--
-- P3 Emails
--

UPDATE  correspondence_templates
    SET subject = 'Your order - [% order_number %]'
WHERE   name = 'Credit Check'
;

-- These Emails are sent via the 'Send Email' menu option
-- on the Order View page and all have the same Subject
UPDATE  correspondence_templates
    SET subject = 'Your order - [% order_number %]'
WHERE   subject IS NULL
AND     name IN (
    'Send order to billing address - Chase Up',
    'Name and Address Check',
    'Name and Address Check - Chase up',
    'Name and Address Check - Final Reminder',
    'Name and Address Check - Same Address Supplied',
    'Name and Address Check - Wrong Address Supplied 2nd Time',
    'Amex - Shipping and Billing Address Different',
    'Amex - Shipping and Billing Address Different - Chase up'
)
;

COMMIT WORK;
