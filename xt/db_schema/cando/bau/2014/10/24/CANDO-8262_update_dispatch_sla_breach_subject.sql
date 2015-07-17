-- CANDO-8262: updates the Subject line for each
--             Brand's Dispatch SLA Breach Email

BEGIN WORK;

-- update NAP
UPDATE  correspondence_templates
    SET subject = 'Your NET-A-PORTER.COM order update - [% order_number %]'
WHERE   name    = 'Dispatch-SLA-Breach-NAP'
AND     department_id IS NULL
;

-- update MRP
UPDATE  correspondence_templates
    SET subject = 'Your MRPORTER.COM order update - [% order_number %]'
WHERE   name    = 'Dispatch-SLA-Breach-MRP'
AND     department_id IS NULL
;

-- update TON
UPDATE  correspondence_templates
    SET subject = 'Your order update - [% order_number %]'
WHERE   name    = 'Dispatch-SLA-Breach-OUTNET'
AND     department_id IS NULL
;

COMMIT WORK;
