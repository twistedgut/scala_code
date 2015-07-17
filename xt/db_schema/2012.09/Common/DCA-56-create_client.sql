-- DCA-56
-- Add client table, link to it from business.
-- For distinguishing between NAP brands and Jimmy Choo for PRLs/IWS.

BEGIN;

    CREATE TABLE public.client (
        id SERIAL NOT NULL,
        name TEXT NOT NULL,
        prl_name TEXT NOT NULL,
        PRIMARY KEY (id),
        UNIQUE (name),
        UNIQUE (prl_name)
    );
    ALTER TABLE public.client OWNER TO www;
    INSERT INTO public.client (name, prl_name)
        VALUES
        ('Net-A-Porter', 'NAP'),
        ('Jimmy Choo', 'CHO')
    ;

    ALTER TABLE public.business
        ADD COLUMN client_id INT REFERENCES public.client(id) DEFERRABLE;

    -- All current businesses except JC are NAP
    UPDATE public.business
        SET client_id = (SELECT id FROM public.client WHERE name = 'Net-A-Porter')
        WHERE NAME != 'JIMMYCHOO.COM';

    UPDATE public.business
        SET client_id = (SELECT id FROM public.client WHERE name = 'Jimmy Choo')
        WHERE NAME = 'JIMMYCHOO.COM';

    ALTER TABLE public.business
        ALTER client_id SET NOT NULL;

COMMIT;
