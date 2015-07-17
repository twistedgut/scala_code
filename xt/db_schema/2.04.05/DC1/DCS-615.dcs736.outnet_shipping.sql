-- http://jira.net-a-porter.com/browse/DCS-736
BEGIN;
    INSERT INTO event.shipping_option
    (id, name)
    VALUES
    (6, 'Outnet Shipping Hack');
COMMIT;
