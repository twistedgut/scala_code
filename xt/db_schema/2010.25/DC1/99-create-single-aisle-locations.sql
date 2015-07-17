BEGIN;

insert into location(location,type_id,channel_id) values
        ('014A001A',1,1),
        ('014A001B',1,3),
        ('014A001C',1,5);

insert into location_allowed_status
       select location.id as location_id,
              flow.status.id as status_id
       from location, flow.status
       where location.location like '014%'
         and flow.status.type_id = (select id from flow.type where name='Stock Status')
         and flow.status.name not ilike '%transfer%';

COMMIT;
