BEGIN;

alter table shipping_attribute add column packing_note_operator_id integer REFERENCES operator(id) DEFERRABLE;
alter table shipping_attribute add column packing_note_date_added timestamp with time zone;

COMMIT;
