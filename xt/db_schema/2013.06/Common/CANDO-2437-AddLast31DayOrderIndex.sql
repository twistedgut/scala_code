BEGIN;

create index orders__last_31_days_idx on orders(channel_id,date);

COMMIT;
