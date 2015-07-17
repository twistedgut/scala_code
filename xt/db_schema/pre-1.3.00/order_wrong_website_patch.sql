-- Purpose:
--  create new promotion class table and update existing promtion type table to cater for revamped promotion system

BEGIN;


-- Create email template
insert into correspondence_templates values (52, 'Ordering from the other site notification email', null, 1, '', 5, null);

-- Create new reason to hold shipment
insert into shipment_hold_reason values (12, 'Order placed on incorrect website');

COMMIT;