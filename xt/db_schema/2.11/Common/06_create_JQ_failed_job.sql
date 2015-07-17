\c job_queue;

BEGIN;
CREATE TABLE failed_job (
    job_id integer NOT NULL,
    func_id integer NOT NULL,
    arg bytea NOT NULL,
    error bytea NOT NULL,
    run_at timestamp with time zone NOT NULL,
    reason character varying NOT NULL,
    priority smallint,
    "coalesce" character varying(255)
);

ALTER TABLE failed_job OWNER TO www;

COMMIT;

