BEGIN;

-- Measure length of time units have been in last/current stock location

alter table quantity add column date_created timestamp with time zone not null default ('now'::text)::timestamp with time zone;

COMMIT;
