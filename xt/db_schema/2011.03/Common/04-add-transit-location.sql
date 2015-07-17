BEGIN;

INSERT
  INTO location ( location, type_id )
VALUES ( 'Transit',
         ( SELECT id
             FROM location_type
            WHERE type = 'In Transit'
         )
       )
     ;

INSERT
  INTO flow.status ( name, type_id, is_initial )
VALUES ( 'In transit from IWS',
         ( SELECT id
             FROM flow.type
            WHERE name = 'Stock Status'
         ),
         true
       )
     ;

INSERT
  INTO location_allowed_status ( location_id, status_id )
VALUES (
         ( SELECT id
             FROM location
            WHERE location = 'Transit'
         ),
         (
           SELECT id
             FROM flow.status
            WHERE name = 'In transit from IWS'
         )
       )
     ;

COMMIT;
