-- we need to edit the name of the email templates to apac

BEGIN;

    UPDATE correspondence_templates
        SET name = 'Special Order Purchase Notification-NAP-APAC'
        WHERE name = 'Special Order Purchase Notification-NAP-AM';

    UPDATE correspondence_templates
        SET name = 'Special Order Purchase Notification-OUTNET-APAC'
        WHERE name = 'Special Order Purchase Notification-OUTNET-AM';

    UPDATE correspondence_templates
        SET name = 'Special Order Purchase Notification-MRP-APAC'
        WHERE name = 'Special Order Purchase Notification-MRP-AM';


    UPDATE correspondence_templates
        SET name = 'Special Order Upload Notification - CC-MRP-APAC'
        WHERE name = 'Special Order Upload Notification - CC-MRP-AM';

    UPDATE correspondence_templates
        SET name = 'Special Order Upload Notification - CC-NAP-APAC'
        WHERE name = 'Special Order Upload Notification - CC-NAP-AM';

    UPDATE correspondence_templates
        SET name = 'Special Order Upload Notification - CC-OUTNET-APAC'
        WHERE name = 'Special Order Upload Notification - CC-OUTNET-AM';


    UPDATE correspondence_templates
        SET name = 'Special Order Upload Notification-MRP-APAC'
        WHERE name = 'Special Order Upload Notification-MRP-AM';

    UPDATE correspondence_templates
        SET name = 'Special Order Upload Notification-NAP-APAC'
        WHERE name = 'Special Order Upload Notification-NAP-AM';

    UPDATE correspondence_templates
        SET name = 'Special Order Upload Notification-OUTNET-APAC'
        WHERE name = 'Special Order Upload Notification-OUTNET-AM';

COMMIT;
