-- Create container tables
BEGIN;
    CREATE TABLE public.container_status (
        id serial PRIMARY KEY,
	name text NOT NULL UNIQUE
    );

    ALTER TABLE public.container_status OWNER to www;

    INSERT
      INTO public.container_status (name)
    VALUES ('Available'),   -- make sure this gets value 1 to make it the default
           ('Picked Items'),
	   ('Packing Exception Items'),
           ('Non-shipment Items')
         ;

    CREATE TABLE public.container (
        id           varchar(255)    PRIMARY KEY,     -- yes, not an auto-increment serial
	status_id    integer         REFERENCES public.container_status(id)
                                       DEFERRABLE
                                       NOT NULL
                                       DEFAULT 1
    );

    ALTER TABLE public.container OWNER to www;

COMMIT;
