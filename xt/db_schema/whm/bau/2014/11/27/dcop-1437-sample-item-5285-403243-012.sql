BEGIN;
 
update sample_request_det
set sample_request_det_status_id = (select id from sample_request_det_status where status = 'Returned'), date_returned = now()
where id = 80400;

insert into sample_request_det_status_log
    (
        sample_request_det_id,
        sample_request_det_status_id,
        location_id_from,
        location_id_to,
        operator_id,
        date
    )
values  (
    80400,
    (select id from sample_request_det_status where status = 'Returned'),
    (select id from location where location = 'Styling'),
    (select id from location where location = 'Sample Room'),
    (select id from operator where name = 'Application'),
    now()   
);

COMMIT;
