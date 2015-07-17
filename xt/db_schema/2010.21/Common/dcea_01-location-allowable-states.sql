BEGIN;

    CREATE TABLE public.location_allowed_status (
       location_id integer REFERENCES public.location(id) DEFERRABLE NOT NULL,
       status_id integer REFERENCES flow.status(id) DEFERRABLE NOT NULL
    );
    ALTER TABLE public.location_allowed_status ADD PRIMARY KEY (location_id, status_id);
    ALTER TABLE public.location_allowed_status OWNER TO www;

COMMIT;
