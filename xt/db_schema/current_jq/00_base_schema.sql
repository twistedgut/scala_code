-- create the database
\connect template1;
CREATE DATABASE job_queue;
\connect job_queue postgres;

--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: dbadmin; Type: SCHEMA; Schema: -; Owner: www
--

CREATE SCHEMA dbadmin;


ALTER SCHEMA dbadmin OWNER TO www;

SET search_path = dbadmin, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: applied_patch; Type: TABLE; Schema: dbadmin; Owner: www; Tablespace: 
--

CREATE TABLE applied_patch (
    id integer NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    filename text NOT NULL,
    basename text NOT NULL,
    succeeded boolean DEFAULT false,
    output text
);


ALTER TABLE dbadmin.applied_patch OWNER TO www;

--
-- Name: md5; Type: TABLE; Schema: dbadmin; Owner: www; Tablespace: 
--

CREATE TABLE md5 (
    applied_patch_id integer,
    b64digest text
);


ALTER TABLE dbadmin.md5 OWNER TO www;

SET search_path = public, pg_catalog;

--
-- Name: error; Type: TABLE; Schema: public; Owner: www; Tablespace: 
--

CREATE TABLE error (
    error_time integer NOT NULL,
    jobid bigint NOT NULL,
    message text NOT NULL,
    funcid integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.error OWNER TO www;

--
-- Name: exitstatus; Type: TABLE; Schema: public; Owner: www; Tablespace: 
--

CREATE TABLE exitstatus (
    jobid integer NOT NULL,
    funcid integer DEFAULT 0 NOT NULL,
    status smallint,
    completion_time integer,
    delete_after integer
);


ALTER TABLE public.exitstatus OWNER TO www;

--
-- Name: failed_job; Type: TABLE; Schema: public; Owner: www; Tablespace: 
--

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


ALTER TABLE public.failed_job OWNER TO www;

--
-- Name: funcmap; Type: TABLE; Schema: public; Owner: www; Tablespace: 
--

CREATE TABLE funcmap (
    funcid integer NOT NULL,
    funcname character varying(255) NOT NULL
);


ALTER TABLE public.funcmap OWNER TO www;

--
-- Name: job; Type: TABLE; Schema: public; Owner: www; Tablespace: 
--

CREATE TABLE job (
    jobid integer NOT NULL,
    funcid integer NOT NULL,
    arg bytea,
    uniqkey character varying(255),
    insert_time integer,
    run_after integer NOT NULL,
    grabbed_until integer NOT NULL,
    priority smallint,
    "coalesce" character varying(255)
);


ALTER TABLE public.job OWNER TO www;

--
-- Name: note; Type: TABLE; Schema: public; Owner: www; Tablespace: 
--

CREATE TABLE note (
    jobid integer NOT NULL,
    notekey character varying(255) NOT NULL,
    value bytea
);


ALTER TABLE public.note OWNER TO www;

SET search_path = dbadmin, pg_catalog;

--
-- Name: applied_patch_id_seq; Type: SEQUENCE; Schema: dbadmin; Owner: www
--

CREATE SEQUENCE applied_patch_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE dbadmin.applied_patch_id_seq OWNER TO www;

--
-- Name: applied_patch_id_seq; Type: SEQUENCE OWNED BY; Schema: dbadmin; Owner: www
--

ALTER SEQUENCE applied_patch_id_seq OWNED BY applied_patch.id;


SET search_path = public, pg_catalog;

--
-- Name: funcmap_funcid_seq; Type: SEQUENCE; Schema: public; Owner: www
--

CREATE SEQUENCE funcmap_funcid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.funcmap_funcid_seq OWNER TO www;

--
-- Name: funcmap_funcid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: www
--

ALTER SEQUENCE funcmap_funcid_seq OWNED BY funcmap.funcid;


--
-- Name: job_jobid_seq; Type: SEQUENCE; Schema: public; Owner: www
--

CREATE SEQUENCE job_jobid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.job_jobid_seq OWNER TO www;

--
-- Name: job_jobid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: www
--

ALTER SEQUENCE job_jobid_seq OWNED BY job.jobid;


SET search_path = dbadmin, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: dbadmin; Owner: www
--

ALTER TABLE applied_patch ALTER COLUMN id SET DEFAULT nextval('applied_patch_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: funcid; Type: DEFAULT; Schema: public; Owner: www
--

ALTER TABLE funcmap ALTER COLUMN funcid SET DEFAULT nextval('funcmap_funcid_seq'::regclass);


--
-- Name: jobid; Type: DEFAULT; Schema: public; Owner: www
--

ALTER TABLE job ALTER COLUMN jobid SET DEFAULT nextval('job_jobid_seq'::regclass);


SET search_path = dbadmin, pg_catalog;

--
-- Name: applied_patch_pkey; Type: CONSTRAINT; Schema: dbadmin; Owner: www; Tablespace: 
--

ALTER TABLE ONLY applied_patch
    ADD CONSTRAINT applied_patch_pkey PRIMARY KEY (id);


SET search_path = public, pg_catalog;

--
-- Name: error_pkey; Type: CONSTRAINT; Schema: public; Owner: www; Tablespace: 
--

ALTER TABLE ONLY error
    ADD CONSTRAINT error_pkey PRIMARY KEY (error_time);


--
-- Name: exitstatus_pkey; Type: CONSTRAINT; Schema: public; Owner: www; Tablespace: 
--

ALTER TABLE ONLY exitstatus
    ADD CONSTRAINT exitstatus_pkey PRIMARY KEY (jobid);


--
-- Name: failed_job_pkey; Type: CONSTRAINT; Schema: public; Owner: www; Tablespace: 
--

ALTER TABLE ONLY failed_job
    ADD CONSTRAINT failed_job_pkey PRIMARY KEY (job_id);


--
-- Name: funcmap_funcname_key; Type: CONSTRAINT; Schema: public; Owner: www; Tablespace: 
--

ALTER TABLE ONLY funcmap
    ADD CONSTRAINT funcmap_funcname_key UNIQUE (funcname);


--
-- Name: funcmap_pkey; Type: CONSTRAINT; Schema: public; Owner: www; Tablespace: 
--

ALTER TABLE ONLY funcmap
    ADD CONSTRAINT funcmap_pkey PRIMARY KEY (funcid);


--
-- Name: job_funcid_key; Type: CONSTRAINT; Schema: public; Owner: www; Tablespace: 
--

ALTER TABLE ONLY job
    ADD CONSTRAINT job_funcid_key UNIQUE (funcid, uniqkey);


--
-- Name: job_pkey; Type: CONSTRAINT; Schema: public; Owner: www; Tablespace: 
--

ALTER TABLE ONLY job
    ADD CONSTRAINT job_pkey PRIMARY KEY (jobid);


--
-- Name: note_pkey; Type: CONSTRAINT; Schema: public; Owner: www; Tablespace: 
--

ALTER TABLE ONLY note
    ADD CONSTRAINT note_pkey PRIMARY KEY (jobid, notekey);


SET search_path = dbadmin, pg_catalog;

--
-- Name: idx_dbadmin_applied_patch_basename; Type: INDEX; Schema: dbadmin; Owner: www; Tablespace: 
--

CREATE INDEX idx_dbadmin_applied_patch_basename ON applied_patch USING btree (basename);


SET search_path = public, pg_catalog;

--
-- Name: idx_error_error_time; Type: INDEX; Schema: public; Owner: www; Tablespace: 
--

CREATE INDEX idx_error_error_time ON error USING btree (error_time);


--
-- Name: idx_error_funcid_error_time; Type: INDEX; Schema: public; Owner: www; Tablespace: 
--

CREATE INDEX idx_error_funcid_error_time ON error USING btree (funcid, error_time);


--
-- Name: idx_error_jobid; Type: INDEX; Schema: public; Owner: www; Tablespace: 
--

CREATE INDEX idx_error_jobid ON error USING btree (jobid);


--
-- Name: idx_exitstatus_delete_after; Type: INDEX; Schema: public; Owner: www; Tablespace: 
--

CREATE INDEX idx_exitstatus_delete_after ON exitstatus USING btree (delete_after);


--
-- Name: idx_exitstatus_funcid; Type: INDEX; Schema: public; Owner: www; Tablespace: 
--

CREATE INDEX idx_exitstatus_funcid ON exitstatus USING btree (funcid);


--
-- Name: idx_job_funcid_coalesce; Type: INDEX; Schema: public; Owner: www; Tablespace: 
--

CREATE INDEX idx_job_funcid_coalesce ON job USING btree (funcid, "coalesce");


--
-- Name: idx_job_funcid_run_after; Type: INDEX; Schema: public; Owner: www; Tablespace: 
--

CREATE INDEX idx_job_funcid_run_after ON job USING btree (funcid, run_after);


SET search_path = dbadmin, pg_catalog;

--
-- Name: md5_applied_patch_id_fkey; Type: FK CONSTRAINT; Schema: dbadmin; Owner: www
--

ALTER TABLE ONLY md5
    ADD CONSTRAINT md5_applied_patch_id_fkey FOREIGN KEY (applied_patch_id) REFERENCES applied_patch(id) DEFERRABLE;


SET search_path = public, pg_catalog;

--
-- Name: failed_job_func_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: www
--

ALTER TABLE ONLY failed_job
    ADD CONSTRAINT failed_job_func_id_fkey FOREIGN KEY (func_id) REFERENCES funcmap(funcid);


--
-- PostgreSQL database dump complete
--

