
-- create the database
\connect template1;
CREATE DATABASE job_queue WITH OWNER="www" ENCODING='utf8';
\connect job_queue www;

BEGIN WORK;

    CREATE TABLE funcmap (
            funcid         SERIAL   primary key,
            funcname       VARCHAR(255) NOT NULL,
            UNIQUE(funcname)
    );

    CREATE TABLE job (
            jobid           SERIAL  primary key,
            funcid          integer NOT NULL,
            arg             bytea,
            uniqkey         VARCHAR(255) NULL,
            insert_time     INTEGER ,
            run_after       INTEGER NOT NULL,
            grabbed_until   INTEGER NOT NULL,
            priority        SMALLINT,
            coalesce        VARCHAR(255),
            UNIQUE(funcid, uniqkey)
    );

    CREATE TABLE note (
            jobid           integer not null,
            notekey         VARCHAR(255),
            PRIMARY KEY (jobid, notekey),
            value           bytea
    );

    CREATE TABLE error (
            error_time      integer     primary key,
            jobid           BIGINT NOT NULL,
            message         text NOT NULL,
            funcid          integer NOT NULL DEFAULT 0
    );

    CREATE TABLE exitstatus (
            jobid           integer     primary key,
            funcid          integer NOT NULL DEFAULT 0,
            status          SMALLINT,
            completion_time INTEGER,
            delete_after    INTEGER
    );

    -- create indexes for tables
    CREATE INDEX idx_job_funcid_run_after       ON job (funcid, run_after);
    CREATE INDEX idx_job_funcid_coalesce        ON job (funcid, coalesce);
    CREATE INDEX idx_error_funcid_error_time    ON error (funcid, error_time);
    CREATE INDEX idx_error_error_time           ON error (error_time);
    CREATE INDEX idx_error_jobid                ON error (jobid);
    CREATE INDEX idx_exitstatus_funcid          ON exitstatus (funcid);
    CREATE INDEX idx_exitstatus_delete_after    ON exitstatus (delete_after);
COMMIT;
