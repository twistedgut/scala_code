BEGIN;

-- Add an MGI location
insert into location (location,type_id,channel_id) values (
    'MGI',
    (select id from location_type where type='DC1'),
    (select id from channel where name='MrPorter.com')
    );
-- Location allowed in Main Stock
insert into location_allowed_status (location_id, status_id) values (
    (select id from location where location='MGI'),
    (select id from flow.status where name='Main Stock')
    );

COMMIT;
