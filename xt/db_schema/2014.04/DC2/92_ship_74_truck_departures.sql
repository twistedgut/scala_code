BEGIN;

-- update two truck departure times and a processing time

update sos.truck_departure
    set departure_time = '11:45:00'
    where carrier_id = (select id from sos.carrier where name = 'NAP')
    and departure_time = '12:00:00';

update sos.truck_departure
    set departure_time = '15:45:00'
    where carrier_id = (select id from sos.carrier where name = 'NAP')
    and departure_time = '15:30:00';

update sos.processing_time
    set processing_time = '01:45:00'
        where class_id in (select id
                            from sos.shipment_class
                            where name = 'Premier');

COMMIT;
