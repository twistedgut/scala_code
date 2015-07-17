-- No-one is quite sure why this index doesn't exist already

BEGIN;

CREATE INDEX stock_process_group_id ON public.stock_process(group_id);

COMMIT;
