BEGIN;

INSERT INTO flow.type (name) VALUES
       ('Stock Status')
;

INSERT INTO flow.status (name,type_id,is_initial) VALUES
       ('Main Stock',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('Transfer Pending',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('RTV Transfer Pending',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('Removed Quarantine',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('Sample',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('Quarantine',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('Creative',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('RTV Goods In',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('RTV Workstation',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('RTV Process',(SELECT id FROM flow.type WHERE name='Stock Status'),true),
       ('Dead stock',(SELECT id FROM flow.type WHERE name='Stock Status'),true)
;

--INSERT INTO flow.next_status (current_status_id,next_status_id) VALUES
--       ()
--;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='Dead stock')
       FROM location
       WHERE type_id = (SELECT id FROM public.location_type WHERE type='Dead Stock')
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='RTV Goods In')
       FROM location
       WHERE type_id = (SELECT id FROM public.location_type WHERE type='RTV Goods In')
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='Main Stock')
       FROM location
       WHERE type_id = (SELECT id FROM public.location_type WHERE type='DC1')
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='Transfer Pending')
       FROM location
       WHERE location.location = 'Transfer Pending';
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='RTV Transfer Pending')
       FROM location
       WHERE location.location = 'RTV Transfer Pending';
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='Removed Quarantine')
       FROM location
       WHERE location.location = 'Removed Quarantine';
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='Creative')
       FROM location
       WHERE type_id = (SELECT id FROM public.location_type WHERE type='Creative')
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='Sample')
       FROM location
       WHERE type_id = (SELECT id FROM public.location_type WHERE type='Sample')
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='RTV Workstation')
       FROM location
       WHERE type_id = (SELECT id FROM public.location_type WHERE type='RTV Workstation')
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='RTV Process')
       FROM location
       WHERE type_id = (SELECT id FROM public.location_type WHERE type='RTV Process')
;

INSERT INTO public.location_allowed_status (location_id,status_id)
       SELECT id,(SELECT id FROM flow.status WHERE name='Quarantine')
       FROM location
       WHERE location.location = 'Quarantine'
;


ALTER TABLE public.quantity DISABLE TRIGGER ALL;

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='Main Stock')
       FROM public.location, public.location_type
       WHERE location.id = quantity.location_id
         AND location.type_id = location_type.id
         AND location_type.type = 'DC1';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='Dead stock')
       FROM public.location, public.location_type
       WHERE location.id = quantity.location_id
         AND location.type_id = location_type.id
         AND location_type.type = 'Dead Stock';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='RTV Goods In')
       FROM public.location, public.location_type
       WHERE location.id = quantity.location_id
         AND location.type_id = location_type.id
         AND location_type.type = 'RTV Goods In';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='RTV to be processed')
       FROM public.location, public.location_type
       WHERE location.id = quantity.location_id
         AND location.type_id = location_type.id
         AND location_type.type = 'RTV Process';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='Transfer Pending')
       FROM public.location
       WHERE location.id = quantity.location_id
         AND location.location = 'Transfer Pending';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='RTV Transfer Pending')
       FROM public.location
       WHERE location.id = quantity.location_id
         AND location.location = 'RTV Transfer Pending';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='Removed Quarantine')
       FROM public.location
       WHERE location.id = quantity.location_id
         AND location.location = 'Removed Quarantine';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='Creative')
       FROM public.location, public.location_type
       WHERE location.id = quantity.location_id
         AND location.type_id = location_type.id
         AND location_type.type = 'Creative';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='Sample')
       FROM public.location, public.location_type
       WHERE location.id = quantity.location_id
         AND location.type_id = location_type.id
         AND location_type.type = 'Sample';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='RTV Workstation')
       FROM public.location, public.location_type
       WHERE location.id = quantity.location_id
         AND location.type_id = location_type.id
         AND location_type.type = 'RTV Workstation';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='RTV Process')
       FROM public.location, public.location_type
       WHERE location.id = quantity.location_id
         AND location.type_id = location_type.id
         AND location_type.type = 'RTV Process';

UPDATE public.quantity
       SET status_id=(SELECT id FROM flow.status WHERE name='Quarantine')
       FROM public.location
       WHERE location.id = quantity.location_id
         AND location.location = 'Quarantine';

ALTER TABLE public.quantity ENABLE TRIGGER ALL;

COMMIT;
