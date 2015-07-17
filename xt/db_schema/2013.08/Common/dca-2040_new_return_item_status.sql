BEGIN;

select setval('return_item_status_id_seq', (select MAX(id) FROM public.return_item_status));

insert into return_item_status (status) values ('Putaway Prep');

COMMIT;

