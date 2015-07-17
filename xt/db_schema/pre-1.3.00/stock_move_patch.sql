-- Purpose:
--  Create new temp tables to represent the "Warehouse location map", basically
--  duplicates of existing tables, for stock to be moved into

BEGIN;

--
-- Name: new_location; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE "new_location" (
    id serial NOT NULL,
    "location" character varying(255),
    type_id integer NOT NULL
);


ALTER TABLE public."new_location" OWNER TO postgres;

--
-- Name: new_location_location_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY "new_location"
    ADD CONSTRAINT new_location_location_key UNIQUE ("location");


--
-- Name: new_location_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY "new_location"
    ADD CONSTRAINT new_location_pkey PRIMARY KEY (id);


--
-- Name: new_location_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "new_location"
    ADD CONSTRAINT new_location_type_id_fkey FOREIGN KEY (type_id) REFERENCES location_type(id);


INSERT INTO "new_location" (location, type_id)
    SELECT location, type_id FROM "location" WHERE type_id != 1;

--
-- Name: new_location; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE "new_location" FROM PUBLIC;
REVOKE ALL ON TABLE "new_location" FROM postgres;
GRANT ALL ON TABLE "new_location" TO postgres;
GRANT ALL ON TABLE "new_location" TO www;


--
-- Name: new_location_id_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE new_location_id_seq FROM PUBLIC;
REVOKE ALL ON TABLE new_location_id_seq FROM postgres;
GRANT ALL ON TABLE new_location_id_seq TO postgres;
GRANT ALL ON TABLE new_location_id_seq TO www;



CREATE TABLE "log_location_move" (
    id serial NOT NULL,
    old_location character varying(8),
    new_location character varying(8),
    date timestamp without time zone DEFAULT ('now'::text)::timestamp(6) with time zone NOT NULL,
    operator_id integer

);

ALTER TABLE ONLY "log_location_move"
    ADD CONSTRAINT log_location_move_pkey PRIMARY KEY (id);

ALTER TABLE ONLY log_location_move
    ADD CONSTRAINT log_location_move_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES "operator"(id);

ALTER TABLE public."log_location_move" OWNER TO postgres;

REVOKE ALL ON TABLE "log_location_move_id_seq" FROM PUBLIC;
REVOKE ALL ON TABLE "log_location_move_id_seq" FROM postgres;
GRANT ALL ON TABLE "log_location_move_id_seq" TO postgres;
GRANT ALL ON TABLE "log_location_move_id_seq" TO www;

REVOKE ALL ON TABLE "log_location_move" FROM PUBLIC;
REVOKE ALL ON TABLE "log_location_move" FROM postgres;
GRANT ALL ON TABLE "log_location_move" TO postgres;
GRANT ALL ON TABLE "log_location_move" TO www;


--
-- Name: log_new_location; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE log_new_location (
    variant_id integer NOT NULL,
    location_id integer NOT NULL,
    date timestamp without time zone DEFAULT ('now'::text)::timestamp(6) with time zone NOT NULL,
    operator_id integer
);


ALTER TABLE public.log_new_location OWNER TO postgres;

--
-- Name: log_new_location_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY log_new_location
    ADD CONSTRAINT log_new_location_pkey PRIMARY KEY (variant_id, location_id, date);


--
-- Name: log_new_location_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_new_location
    ADD CONSTRAINT log_new_location_location_id_fkey FOREIGN KEY (location_id) REFERENCES "new_location"(id);


--
-- Name: log_new_location_operator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_new_location
    ADD CONSTRAINT log_new_location_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES "operator"(id);


--
-- Name: log_new_location_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_new_location
    ADD CONSTRAINT log_new_location_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES variant(id);

--
-- Name: log_new_location; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE log_new_location FROM PUBLIC;
REVOKE ALL ON TABLE log_new_location FROM postgres;
GRANT ALL ON TABLE log_new_location TO postgres;
GRANT ALL ON TABLE log_new_location TO www;

--
-- Name: new_putaway; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE new_putaway (
    stock_process_id integer NOT NULL,
    location_id integer NOT NULL,
    quantity integer,
    "timestamp" timestamp without time zone DEFAULT ('now'::text)::timestamp(6) with time zone NOT NULL,
    complete integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.new_putaway OWNER TO postgres;

--
-- Name: new_putaway_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY new_putaway
    ADD CONSTRAINT new_putaway_pkey PRIMARY KEY (stock_process_id, location_id);


--
-- Name: new_putaway_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY new_putaway
    ADD CONSTRAINT new_putaway_location_id_fkey FOREIGN KEY (location_id) REFERENCES "new_location"(id);


--
-- Name: new_putaway_stock_process_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY new_putaway
    ADD CONSTRAINT new_putaway_stock_process_id_fkey FOREIGN KEY (stock_process_id) REFERENCES stock_process(id);


--
-- Name: new_putaway; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE new_putaway FROM PUBLIC;
REVOKE ALL ON TABLE new_putaway FROM postgres;
GRANT ALL ON TABLE new_putaway TO postgres;
GRANT ALL ON TABLE new_putaway TO www;


--
-- Name: new_quantity_audit_sp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION new_quantity_audit_sp() RETURNS "trigger"
    AS $$
declare
begin
    insert into quantity_audit ( variant, oldquantity, newquantity )
    values ( old.variant_id, old.quantity, new.quantity );
    return null;
end;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.new_quantity_audit_sp() OWNER TO postgres;


--
-- Name: new_t_set_final_pick_date(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION new_t_set_final_pick_date() RETURNS "trigger"
    AS $$
DECLARE
    new_quant INTEGER := NEW.quantity;
BEGIN

    IF new_quant = 0 THEN
        NEW.zero_date := current_timestamp;
    ELSE
        NEW.zero_date := NULL;
    END IF;

    RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.new_t_set_final_pick_date() OWNER TO postgres;


--
-- Name: new_quantity; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE new_quantity (
    id serial NOT NULL,
    variant_id integer NOT NULL,
    location_id integer NOT NULL,
    quantity integer NOT NULL,
    zero_date timestamp without time zone
);


ALTER TABLE public.new_quantity OWNER TO postgres;

--
-- Name: new_quantity_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY new_quantity
    ADD CONSTRAINT new_quantity_pkey PRIMARY KEY (id);


--
-- Name: new_quantity_variant_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX new_quantity_variant_id_key ON new_quantity USING btree (variant_id);


--
-- Name: new_quantity_audit_tr; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_quantity_audit_tr
    AFTER UPDATE ON new_quantity
    FOR EACH ROW
    EXECUTE PROCEDURE new_quantity_audit_sp();


--
-- Name: t_set_final_pick_date; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_t_set_final_pick_date
    BEFORE UPDATE ON new_quantity
    FOR EACH ROW
    EXECUTE PROCEDURE t_set_final_pick_date();


--
-- Name: new_quantity_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY new_quantity
    ADD CONSTRAINT new_quantity_location_id_fkey FOREIGN KEY (location_id) REFERENCES "new_location"(id);


--
-- Name: new_quantity_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY new_quantity
    ADD CONSTRAINT new_quantity_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES variant(id);


--
-- Name: new_quantity; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE new_quantity FROM PUBLIC;
REVOKE ALL ON TABLE new_quantity FROM postgres;
GRANT ALL ON TABLE new_quantity TO postgres;
GRANT ALL ON TABLE new_quantity TO www;


--
-- Name: new_quantity_id_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE new_quantity_id_seq FROM PUBLIC;
REVOKE ALL ON TABLE new_quantity_id_seq FROM postgres;
GRANT ALL ON TABLE new_quantity_id_seq TO postgres;
GRANT ALL ON TABLE new_quantity_id_seq TO www;

COMMIT;