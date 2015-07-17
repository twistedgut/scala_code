BEGIN;

ALTER TABLE public.rtv_quantity
 ADD COLUMN status_id integer REFERENCES flow.status(id) DEFERRABLE
;

ALTER TABLE public.rtv_nonfaulty_location
 ADD COLUMN quantity_status_id integer REFERENCES flow.status(id) DEFERRABLE
;

ALTER TABLE public.rtv_shipment_pick
 ADD COLUMN quantity_status_id integer REFERENCES flow.status(id) DEFERRABLE
;

ALTER TABLE public.rtv_inspection_pick
 ADD COLUMN quantity_status_id integer REFERENCES flow.status(id) DEFERRABLE
;


UPDATE public.rtv_quantity
   SET status_id = (
       CASE WHEN location_type.type = 'DC1' THEN (SELECT id FROM flow.status WHERE name='Main Stock')
            WHEN location_type.type = 'RTV to be processed' THEN (SELECT id FROM flow.status WHERE name='RTV Process')
            ELSE (SELECT id FROM flow.status WHERE name=location_type.type)
       END
   )
  FROM public.location JOIN public.location_type ON (location.type_id = location_type.id)
 WHERE location.id = public.rtv_quantity.location_id
;

UPDATE public.rtv_nonfaulty_location
   SET quantity_status_id = (
       CASE WHEN location_type.type = 'DC1' THEN (SELECT id FROM flow.status WHERE name='Main Stock')
            WHEN location_type.type = 'RTV to be processed' THEN (SELECT id FROM flow.status WHERE name='RTV Process')
            WHEN location.location = 'RTV Transit Pending' THEN (SELECT id FROM flow.status WHERE name='RTV Transfer Pending')
            ELSE (SELECT id FROM flow.status WHERE name=location_type.type)
       END
   )
  FROM public.location JOIN public.location_type ON (location.type_id = location_type.id)
 WHERE location.location = public.rtv_nonfaulty_location.original_location
;

UPDATE public.rtv_shipment_pick
   SET quantity_status_id = (
       CASE WHEN location_type.type = 'DC1' THEN (SELECT id FROM flow.status WHERE name='Main Stock')
            WHEN location_type.type = 'RTV to be processed' THEN (SELECT id FROM flow.status WHERE name='RTV Process')
            WHEN location.location = 'RTV Transit Pending' THEN (SELECT id FROM flow.status WHERE name='RTV Transfer Pending')
            ELSE (SELECT id FROM flow.status WHERE name=location_type.type)
       END
   )
  FROM public.location JOIN public.location_type ON (location.type_id = location_type.id)
 WHERE location.location = public.rtv_shipment_pick.location
;

UPDATE public.rtv_inspection_pick
   SET quantity_status_id = (
       CASE WHEN location_type.type = 'DC1' THEN (SELECT id FROM flow.status WHERE name='Main Stock')
            WHEN location_type.type = 'RTV to be processed' THEN (SELECT id FROM flow.status WHERE name='RTV Process')
            WHEN location.location = 'RTV Transit Pending' THEN (SELECT id FROM flow.status WHERE name='RTV Transfer Pending')
            ELSE (SELECT id FROM flow.status WHERE name=location_type.type)
       END

   )
  FROM public.location JOIN public.location_type ON (location.type_id = location_type.id)
 WHERE location.location = public.rtv_inspection_pick.location
;


--ALTER TABLE public.rtv_quantity           ALTER COLUMN status_id          SET NOT NULL;
--ALTER TABLE public.rtv_inspection_pick    ALTER COLUMN quantity_status_id SET NOT NULL;
--ALTER TABLE public.rtv_shipment_pick      ALTER COLUMN quantity_status_id SET NOT NULL;
--ALTER TABLE public.rtv_nonfaulty_location ALTER COLUMN quantity_status_id SET NOT NULL;

COMMIT;
