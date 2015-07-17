BEGIN;

update public.routing_export set channel_id = 2 where channel_id is null;

COMMIT;
