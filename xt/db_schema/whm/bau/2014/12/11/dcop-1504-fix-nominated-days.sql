
-- Fix the Nominated Day and SLA values on a number of shipments that have
-- incorrect values (DCOP-1504)

BEGIN WORK;

update shipment
set sla_cutoff = '2014-12-12 07:30:00+00',
    nominated_dispatch_time = '2014-12-12 17:00:00+00',
    nominated_earliest_selection_time = '2014-12-11 18:00:00+00'
where id in (
6435849,
6437428,
6446967,
6448213,
6448638,
6450441,
6451325,
6451488,
6455223,
6455910,
6456312,
6457104,
6458141,
6458530,
6459015,
6459085,
6459113,
6459239,
6460948
);

COMMIT;
