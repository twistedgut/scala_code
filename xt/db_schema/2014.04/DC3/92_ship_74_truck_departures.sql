BEGIN;

-- update one truck departure time

update sos.truck_departure
    set departure_time = '20:00:00'
    where carrier_id = (select id from sos.carrier where name = 'DHL')
    and departure_time = '19:30:00';

COMMIT;

