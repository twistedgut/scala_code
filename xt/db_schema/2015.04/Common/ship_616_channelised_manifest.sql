BEGIN;

    CREATE TABLE public.link_manifest__channel (
        manifest_id INT REFERENCES manifest(id) NOT NULL,
        channel_id INT REFERENCES channel(id) NOT NULL
    );
    ALTER TABLE public.link_manifest__channel OWNER TO www;

COMMIT;