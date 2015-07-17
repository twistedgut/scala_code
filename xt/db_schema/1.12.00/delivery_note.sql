-- Create delivery notes table

BEGIN;

CREATE TABLE delivery_note (
    id          serial primary key,
    created_by  integer REFERENCES operator(id) NOT NULL,
    created     timestamptz NOT NULL,
    modified_by integer REFERENCES operator(id),
    modified    timestamptz,
    description text NOT NULL,
    delivery_id integer REFERENCES delivery(id)
);

GRANT ALL ON public.delivery_note TO www;
GRANT ALL ON public.delivery_note_id_seq TO www;

COMMIT;
