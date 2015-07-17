-- CANDO-8651: Add Back-Fill Tables

BEGIN WORK;

-- this means the 'dbadmin.' prefix is not required
SET search_path = dbadmin, pg_catalog;


--
-- Table: back_fill_job_status
--
CREATE TABLE back_fill_job_status (
    id          SERIAL PRIMARY KEY,
    status      TEXT NOT NULL
);
-- comments
    COMMENT ON TABLE back_fill_job_status IS 'This holds the different Statuses that can be applied to the ''dbadmin.back_fill_job'' records.';
-- end of comments
CREATE UNIQUE INDEX idx_uniq_back_fill_job_status__status ON back_fill_job_status ( LOWER(status::text) );
ALTER TABLE back_fill_job_status OWNER TO www;
GRANT ALL ON SEQUENCE back_fill_job_status_id_seq TO www;


--
-- Table: back_fill_job
--
CREATE TABLE back_fill_job (
    id                              SERIAL PRIMARY KEY,
    name                            CHARACTER VARYING(150) NOT NULL,
    description                     TEXT NOT NULL,
    back_fill_job_status_id         INTEGER NOT NULL REFERENCES back_fill_job_status(id),
    back_fill_table_name            TEXT NOT NULL,
    back_fill_primary_key_field     TEXT NOT NULL,
    update_set                      TEXT NOT NULL,
    resultset_select                TEXT,
    resultset_from                  TEXT NOT NULL,
    resultset_where                 TEXT NOT NULL,
    resultset_order_by              TEXT,
    max_rows_to_update              INTEGER NOT NULL,
    max_jobs_to_create              INTEGER NOT NULL,
    time_to_start_back_fill         TIMESTAMP WITH TIME ZONE NOT NULL,
    contact_email_address           TEXT NOT NULL,
    created                         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
-- comments
    COMMENT ON TABLE back_fill_job
        IS 'This hold the details of the Tables & Fields that require to be Back-filled after a change to the DB Schema. An Update will be done against a Result-Set that will be built based on the ''resultset_'' prefixed fields and the Fields to be updated along with the Values will be defined in the ''update_set'' field.';
    COMMENT ON COLUMN back_fill_job.name
        IS 'A unique name to give this Back-Fill Job';
    COMMENT ON COLUMN back_fill_job.description
        IS 'A description for the Job that can give more information that the ''name'' such as a JIRA Ticket.';
    COMMENT ON COLUMN back_fill_job.back_fill_table_name
        IS 'The name of the Table that will be back-filled, this should include the ''schema'' prefix for the table if the table isn''t in the ''public'' schema.';
    COMMENT ON COLUMN back_fill_job.back_fill_primary_key_field
        IS 'The name of the field that''s the back-fill table''s Primary Key.';
    COMMENT ON COLUMN back_fill_job.update_set
        IS 'A Raw SQL string that will form the ''SET'' part of the UPDATE statement that will actually do the back-filling of the new Columns.';
    COMMENT ON COLUMN back_fill_job.resultset_select
        IS 'This is optional and only required if the Result-Set query has joins to tables where there are other fields with the same name as the Primary Key such as ''id'' fields. When this is blank then the Result-Set query will be built using ''SELECT [back_fill_primary_key_field]''.';
    COMMENT ON COLUMN back_fill_job.resultset_from
        IS 'The FROM part of the query that will build the Result-Set.';
    COMMENT ON COLUMN back_fill_job.resultset_where
        IS 'The WHERE part of the query that will build the Result-Set.';
    COMMENT ON COLUMN back_fill_job.resultset_order_by
        IS 'This is optional and is the ORDER BY part of the query that will build the Result-Set.';
    COMMENT ON COLUMN back_fill_job.max_rows_to_update
        IS 'The number of Rows that will be Updated at a time, this will form the LIMIT part of the Query for the Result-Set.';
    COMMENT ON COLUMN back_fill_job.max_jobs_to_create
        IS 'The Number of Jobs to be created on the Job Queue for this Back-Fill Job each time. This will enable you to back-fill more rows faster, but will result in different Jobs created meaning the DB is not stressed out doing the same query all the time. This can be done by setting the ''max_rows_to_update'' to 1000 and the ''max_jobs_to_create'' to 5 which allows you to update 5000 records at a "time" but not have one query open all the time whilst they are being updated.';
    COMMENT ON COLUMN back_fill_job.time_to_start_back_fill
        IS 'The time when the Back-Fill Job can start to be run from, this then allows you to prevent the Back-filling being kicked off immediately after Deployment if that''s something that you don''t want to happen as you might want to make sure the Deployment is ok before starting to Back-fill fields. This field must have a Value but deliberately doesn''t have a default, use ''now()'' when creating the record if you want the Back-Fill to start after deployment.';
    COMMENT ON COLUMN back_fill_job.contact_email_address
        IS 'This email Address should be used when the Back-fill Job has been Completed or if the Status has been set to ''On Hold'' or ''Cancelled'' to alert DEVs or a DEV Team of what has happened.';
    COMMENT ON COLUMN back_fill_job.created
        IS 'The time the record gets created, these records should be created as part of the DB Patches that get deployed and so will reflect the time the Deployment happened.';
-- end of comments
CREATE UNIQUE INDEX idx_uniq_back_fill_job__name ON back_fill_job ( LOWER(name::text) );
ALTER TABLE back_fill_job OWNER TO www;
GRANT ALL ON SEQUENCE back_fill_job_id_seq TO www;


--
-- Table: log_back_fill_job_status
--
CREATE TABLE log_back_fill_job_status (
    id                          SERIAL PRIMARY KEY,
    back_fill_job_id            INTEGER NOT NULL REFERENCES back_fill_job(id),
    back_fill_job_status_id     INTEGER NOT NULL REFERENCES back_fill_job_status(id),
    operator_id                 INTEGER NOT NULL REFERENCES public.operator(id),
    log_date                    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
-- comments
    COMMENT ON TABLE log_back_fill_job_status IS 'To log changes to the Status of the ''back_fill_job'' table.';
-- end of comments
ALTER TABLE log_back_fill_job_status OWNER TO www;
GRANT ALL ON SEQUENCE log_back_fill_job_status_id_seq TO www;


--
-- Table: log_back_fill_job_run
--
CREATE TABLE log_back_fill_job_run (
    id                      SERIAL PRIMARY KEY,
    back_fill_job_id        INTEGER NOT NULL REFERENCES back_fill_job(id),
    number_of_rows_updated  INTEGER NOT NULL,
    error_was_thrown        BOOLEAN NOT NULL,
    start_time              TIMESTAMP WITH TIME ZONE NOT NULL,
    finish_time             TIMESTAMP WITH TIME ZONE NOT NULL,
    operator_id             INTEGER NOT NULL REFERENCES public.operator(id)
);
-- comments
    COMMENT ON TABLE log_back_fill_job_run
        IS 'This table Logs each time a Job is run, this also capture the number of records updated so that they can be summed up to give the total number of records updated by the back-fill job as a whole. Also captures the Start and Finish Time of each run so that we can see how long each run takes.';
    COMMENT ON COLUMN log_back_fill_job_run.error_was_thrown
        IS 'This is a boolean and will be TRUE if whilst the Back-Fill Job was run an Error was Thrown.';
    COMMENT ON COLUMN log_back_fill_job_run.operator_id
        IS 'This is the Operator who kicked off the Job, in most cases this will be the Application Operator as the Job Queue will be the one that runs the Job, but if it is facilitated that an Operator can kick the Job off themselves then their Operator Id should be used.';
-- end of comments
ALTER TABLE log_back_fill_job_run OWNER TO www;
GRANT ALL ON SEQUENCE log_back_fill_job_run_id_seq TO www;


--
-- Populate 'back_fill_job_status' table
--
INSERT INTO back_fill_job_status (status) VALUES
    ('New'),
    ('In Progress'),
    ('Completed'),
    ('On Hold'),
    ('Cancelled')
;


COMMIT WORK;
