-- Add the following tables to be the same as DC1's Schema:
--    routing_export
--    routing_export_status
--    routing_export_status_log
--    link_routing_export__shipment
--    link_routing_export__return

BEGIN WORK;

--
-- Name: link_routing_export__shipment; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE link_routing_export__shipment (
    routing_export_id integer NOT NULL,
    shipment_id integer NOT NULL
);


ALTER TABLE public.link_routing_export__shipment OWNER TO postgres;

--
-- Name: routing_export; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE routing_export (
    id integer NOT NULL,
    filename character varying(255) NOT NULL,
    cut_off timestamp without time zone NOT NULL,
    status_id integer NOT NULL
);


ALTER TABLE public.routing_export OWNER TO postgres;

--
-- Name: routing_export_status; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE routing_export_status (
    id integer NOT NULL,
    status character varying(255) NOT NULL
);


ALTER TABLE public.routing_export_status OWNER TO postgres;

--
-- Name: routing_export_status_log; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE routing_export_status_log (
    id integer NOT NULL,
    routing_export_id integer NOT NULL,
    status_id integer NOT NULL,
    operator_id integer NOT NULL,
    date timestamp without time zone NOT NULL
);


ALTER TABLE public.routing_export_status_log OWNER TO postgres;

--
-- Name: routing_export_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE routing_export_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.routing_export_id_seq OWNER TO postgres;

--
-- Name: routing_export_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE routing_export_id_seq OWNED BY routing_export.id;


--
-- Name: routing_export_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE routing_export_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.routing_export_status_id_seq OWNER TO postgres;

--
-- Name: routing_export_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE routing_export_status_id_seq OWNED BY routing_export_status.id;


--
-- Name: routing_export_status_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE routing_export_status_log_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.routing_export_status_log_id_seq OWNER TO postgres;

--
-- Name: routing_export_status_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE routing_export_status_log_id_seq OWNED BY routing_export_status_log.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE routing_export ALTER COLUMN id SET DEFAULT nextval('routing_export_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE routing_export_status ALTER COLUMN id SET DEFAULT nextval('routing_export_status_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE routing_export_status_log ALTER COLUMN id SET DEFAULT nextval('routing_export_status_log_id_seq'::regclass);


--
-- Name: routing_export_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY routing_export
    ADD CONSTRAINT routing_export_pkey PRIMARY KEY (id);


--
-- Name: routing_export_status_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY routing_export_status_log
    ADD CONSTRAINT routing_export_status_log_pkey PRIMARY KEY (id);


--
-- Name: routing_export_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY routing_export_status
    ADD CONSTRAINT routing_export_status_pkey PRIMARY KEY (id);


--
-- Name: link_routing_export__shipment_routing_export_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY link_routing_export__shipment
    ADD CONSTRAINT link_routing_export__shipment_routing_export_id_fkey FOREIGN KEY (routing_export_id) REFERENCES routing_export(id);


--
-- Name: link_routing_export__shipment_shipment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY link_routing_export__shipment
    ADD CONSTRAINT link_routing_export__shipment_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES shipment(id);


--
-- Name: routing_export_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY routing_export
    ADD CONSTRAINT routing_export_status_id_fkey FOREIGN KEY (status_id) REFERENCES routing_export_status(id);


--
-- Name: routing_export_status_log_operator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY routing_export_status_log
    ADD CONSTRAINT routing_export_status_log_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES operator(id);


--
-- Name: routing_export_status_log_routing_export_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY routing_export_status_log
    ADD CONSTRAINT routing_export_status_log_routing_export_id_fkey FOREIGN KEY (routing_export_id) REFERENCES routing_export(id);


--
-- Name: routing_export_status_log_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY routing_export_status_log
    ADD CONSTRAINT routing_export_status_log_status_id_fkey FOREIGN KEY (status_id) REFERENCES routing_export_status(id);


--
-- Name: link_routing_export__shipment; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE link_routing_export__shipment FROM PUBLIC;
REVOKE ALL ON TABLE link_routing_export__shipment FROM postgres;
GRANT ALL ON TABLE link_routing_export__shipment TO postgres;
GRANT ALL ON TABLE link_routing_export__shipment TO www;


--
-- Name: routing_export; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE routing_export FROM PUBLIC;
REVOKE ALL ON TABLE routing_export FROM postgres;
GRANT ALL ON TABLE routing_export TO postgres;
GRANT ALL ON TABLE routing_export TO www;


--
-- Name: routing_export_status; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE routing_export_status FROM PUBLIC;
REVOKE ALL ON TABLE routing_export_status FROM postgres;
GRANT ALL ON TABLE routing_export_status TO postgres;
GRANT ALL ON TABLE routing_export_status TO www;


--
-- Name: routing_export_status_log; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE routing_export_status_log FROM PUBLIC;
REVOKE ALL ON TABLE routing_export_status_log FROM postgres;
GRANT ALL ON TABLE routing_export_status_log TO postgres;
GRANT ALL ON TABLE routing_export_status_log TO www;


--
-- Name: routing_export_id_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE routing_export_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE routing_export_id_seq FROM postgres;
GRANT ALL ON SEQUENCE routing_export_id_seq TO postgres;
GRANT ALL ON SEQUENCE routing_export_id_seq TO www;


--
-- Name: routing_export_status_id_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE routing_export_status_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE routing_export_status_id_seq FROM postgres;
GRANT ALL ON SEQUENCE routing_export_status_id_seq TO postgres;
GRANT ALL ON SEQUENCE routing_export_status_id_seq TO www;


--
-- Name: routing_export_status_log_id_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE routing_export_status_log_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE routing_export_status_log_id_seq FROM postgres;
GRANT ALL ON SEQUENCE routing_export_status_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE routing_export_status_log_id_seq TO www;

--
-- Name: link_routing_export__return; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE link_routing_export__return (
    routing_export_id integer NOT NULL,
    return_id integer NOT NULL
);


ALTER TABLE public.link_routing_export__return OWNER TO postgres;

--
-- Name: link_routing_export__return_return_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY link_routing_export__return
    ADD CONSTRAINT link_routing_export__return_return_id_fkey FOREIGN KEY (return_id) REFERENCES return(id);


--
-- Name: link_routing_export__return_routing_export_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY link_routing_export__return
    ADD CONSTRAINT link_routing_export__return_routing_export_id_fkey FOREIGN KEY (routing_export_id) REFERENCES routing_export(id);


--
-- Name: link_routing_export__return; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE link_routing_export__return FROM PUBLIC;
REVOKE ALL ON TABLE link_routing_export__return FROM postgres;
GRANT ALL ON TABLE link_routing_export__return TO postgres;
GRANT ALL ON TABLE link_routing_export__return TO www;

COMMIT WORK;
