--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: delivery; Type: SCHEMA; Schema: -; Owner: sos
--

CREATE SCHEMA delivery;


ALTER SCHEMA delivery OWNER TO sos;

--
-- Name: shipping; Type: SCHEMA; Schema: -; Owner: sos
--

CREATE SCHEMA shipping;


ALTER SCHEMA shipping OWNER TO sos;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner:
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner:
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = shipping, pg_catalog;

--
-- Name: shipping_attribute(text); Type: FUNCTION; Schema: shipping; Owner: sos
--

CREATE FUNCTION shipping_attribute(text) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$SELECT id FROM shipping.attribute WHERE code=$1$_$;


ALTER FUNCTION shipping.shipping_attribute(text) OWNER TO sos;

SET search_path = delivery, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: event; Type: TABLE; Schema: delivery; Owner: sos; Tablespace:
--

CREATE TABLE event (
    id integer NOT NULL,
    carrier_id integer NOT NULL,
    order_number text NOT NULL,
    waybill_number text NOT NULL,
    delivery_event_type_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    broadcast_at timestamp with time zone,
    event_happened_at timestamp with time zone NOT NULL
);


ALTER TABLE delivery.event OWNER TO sos;

--
-- Name: event_id_seq; Type: SEQUENCE; Schema: delivery; Owner: sos
--

CREATE SEQUENCE event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery.event_id_seq OWNER TO sos;

--
-- Name: event_id_seq; Type: SEQUENCE OWNED BY; Schema: delivery; Owner: sos
--

ALTER SEQUENCE event_id_seq OWNED BY event.id;


--
-- Name: event_type; Type: TABLE; Schema: delivery; Owner: sos; Tablespace:
--

CREATE TABLE event_type (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE delivery.event_type OWNER TO sos;

--
-- Name: event_type_id_seq; Type: SEQUENCE; Schema: delivery; Owner: sos
--

CREATE SEQUENCE event_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery.event_type_id_seq OWNER TO sos;

--
-- Name: event_type_id_seq; Type: SEQUENCE OWNED BY; Schema: delivery; Owner: sos
--

ALTER SEQUENCE event_type_id_seq OWNED BY event_type.id;


--
-- Name: file; Type: TABLE; Schema: delivery; Owner: sos; Tablespace:
--

CREATE TABLE file (
    id integer NOT NULL,
    carrier_id integer NOT NULL,
    filename text NOT NULL,
    remote_modification_epoch integer NOT NULL,
    number_of_failures integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone
);


ALTER TABLE delivery.file OWNER TO sos;

--
-- Name: file_id_seq; Type: SEQUENCE; Schema: delivery; Owner: sos
--

CREATE SEQUENCE file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery.file_id_seq OWNER TO sos;

--
-- Name: file_id_seq; Type: SEQUENCE OWNED BY; Schema: delivery; Owner: sos
--

ALTER SEQUENCE file_id_seq OWNED BY file.id;


--
-- Name: restriction; Type: TABLE; Schema: delivery; Owner: sos; Tablespace:
--

CREATE TABLE restriction (
    id integer NOT NULL,
    restricted_date date NOT NULL,
    shipping_availability_id integer NOT NULL,
    is_restricted boolean NOT NULL,
    stage_id integer NOT NULL
);


ALTER TABLE delivery.restriction OWNER TO sos;

--
-- Name: restriction_id_seq; Type: SEQUENCE; Schema: delivery; Owner: sos
--

CREATE SEQUENCE restriction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery.restriction_id_seq OWNER TO sos;

--
-- Name: restriction_id_seq; Type: SEQUENCE OWNED BY; Schema: delivery; Owner: sos
--

ALTER SEQUENCE restriction_id_seq OWNED BY restriction.id;


--
-- Name: stage; Type: TABLE; Schema: delivery; Owner: sos; Tablespace:
--

CREATE TABLE stage (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    ranking integer NOT NULL
);


ALTER TABLE delivery.stage OWNER TO sos;

--
-- Name: stage_days_to_complete; Type: TABLE; Schema: delivery; Owner: sos; Tablespace:
--

CREATE TABLE stage_days_to_complete (
    id integer NOT NULL,
    shipping_availability_id integer NOT NULL,
    stage_id integer NOT NULL,
    days_to_complete integer NOT NULL
);


ALTER TABLE delivery.stage_days_to_complete OWNER TO sos;

--
-- Name: stage_days_to_complete_id_seq; Type: SEQUENCE; Schema: delivery; Owner: sos
--

CREATE SEQUENCE stage_days_to_complete_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery.stage_days_to_complete_id_seq OWNER TO sos;

--
-- Name: stage_days_to_complete_id_seq; Type: SEQUENCE OWNED BY; Schema: delivery; Owner: sos
--

ALTER SEQUENCE stage_days_to_complete_id_seq OWNED BY stage_days_to_complete.id;


--
-- Name: stage_id_seq; Type: SEQUENCE; Schema: delivery; Owner: sos
--

CREATE SEQUENCE stage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery.stage_id_seq OWNER TO sos;

--
-- Name: stage_id_seq; Type: SEQUENCE OWNED BY; Schema: delivery; Owner: sos
--

ALTER SEQUENCE stage_id_seq OWNED BY stage.id;


SET search_path = public, pg_catalog;

--
-- Name: business; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE business (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE public.business OWNER TO sos;

--
-- Name: business_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE business_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.business_id_seq OWNER TO sos;

--
-- Name: business_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE business_id_seq OWNED BY business.id;


--
-- Name: carrier; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE carrier (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE public.carrier OWNER TO sos;

--
-- Name: carrier_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE carrier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.carrier_id_seq OWNER TO sos;

--
-- Name: carrier_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE carrier_id_seq OWNED BY carrier.id;


--
-- Name: country; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE country (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE public.country OWNER TO sos;

--
-- Name: country_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE country_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.country_id_seq OWNER TO sos;

--
-- Name: country_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE country_id_seq OWNED BY country.id;


--
-- Name: currency; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE currency (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE public.currency OWNER TO sos;

--
-- Name: currency_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE currency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.currency_id_seq OWNER TO sos;

--
-- Name: currency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE currency_id_seq OWNED BY currency.id;


--
-- Name: databasechangelog; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp with time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20)
);


ALTER TABLE public.databasechangelog OWNER TO sos;

--
-- Name: databasechangeloglock; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp with time zone,
    lockedby character varying(255)
);


ALTER TABLE public.databasechangeloglock OWNER TO sos;

--
-- Name: dc; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE dc (
    id integer NOT NULL,
    code character varying(10) NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.dc OWNER TO sos;

--
-- Name: dc_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE dc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dc_id_seq OWNER TO sos;

--
-- Name: dc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE dc_id_seq OWNED BY dc.id;


--
-- Name: division; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE division (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    country_id integer NOT NULL
);


ALTER TABLE public.division OWNER TO sos;

--
-- Name: division_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE division_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.division_id_seq OWNER TO sos;

--
-- Name: division_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE division_id_seq OWNED BY division.id;


--
-- Name: language; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE language (
    id integer NOT NULL,
    code text NOT NULL,
    description text NOT NULL
);


ALTER TABLE public.language OWNER TO sos;

--
-- Name: language_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.language_id_seq OWNER TO sos;

--
-- Name: language_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE language_id_seq OWNED BY language.id;


--
-- Name: locale; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE locale (
    id integer NOT NULL,
    country_id integer NOT NULL,
    language_id integer NOT NULL
);


ALTER TABLE public.locale OWNER TO sos;

--
-- Name: locale_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE locale_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.locale_id_seq OWNER TO sos;

--
-- Name: locale_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE locale_id_seq OWNED BY locale.id;


--
-- Name: post_code; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE post_code (
    id integer NOT NULL,
    code text NOT NULL,
    country_id integer NOT NULL
);


ALTER TABLE public.post_code OWNER TO sos;

--
-- Name: post_code_group; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE post_code_group (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE public.post_code_group OWNER TO sos;

--
-- Name: post_code_group_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE post_code_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.post_code_group_id_seq OWNER TO sos;

--
-- Name: post_code_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE post_code_group_id_seq OWNED BY post_code_group.id;


--
-- Name: post_code_group_member; Type: TABLE; Schema: public; Owner: sos; Tablespace:
--

CREATE TABLE post_code_group_member (
    post_code_group_id integer NOT NULL,
    post_code_id integer NOT NULL
);


ALTER TABLE public.post_code_group_member OWNER TO sos;

--
-- Name: post_code_id_seq; Type: SEQUENCE; Schema: public; Owner: sos
--

CREATE SEQUENCE post_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.post_code_id_seq OWNER TO sos;

--
-- Name: post_code_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sos
--

ALTER SEQUENCE post_code_id_seq OWNED BY post_code.id;


SET search_path = shipping, pg_catalog;

--
-- Name: attribute; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE attribute (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE shipping.attribute OWNER TO sos;

--
-- Name: attribute_id_seq; Type: SEQUENCE; Schema: shipping; Owner: sos
--

CREATE SEQUENCE attribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shipping.attribute_id_seq OWNER TO sos;

--
-- Name: attribute_id_seq; Type: SEQUENCE OWNED BY; Schema: shipping; Owner: sos
--

ALTER SEQUENCE attribute_id_seq OWNED BY attribute.id;


--
-- Name: availability; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE availability (
    id integer NOT NULL,
    option_id integer NOT NULL,
    country_id integer,
    business_id integer NOT NULL,
    is_enabled boolean NOT NULL,
    is_customer_facing boolean NOT NULL,
    price numeric(10,2) NOT NULL,
    currency_id integer NOT NULL,
    does_price_include_tax boolean NOT NULL,
    legacy_sku text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    signature_required_status_id integer NOT NULL,
    customer_selectable_cutoff_time time with time zone,
    customer_selectable_offset integer,
    division_id integer,
    post_code_group_id integer,
    packaging_group_id integer,
    "DC" character varying(10) NOT NULL
);


ALTER TABLE shipping.availability OWNER TO sos;

--
-- Name: availability_id_seq; Type: SEQUENCE; Schema: shipping; Owner: sos
--

CREATE SEQUENCE availability_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shipping.availability_id_seq OWNER TO sos;

--
-- Name: availability_id_seq; Type: SEQUENCE OWNED BY; Schema: shipping; Owner: sos
--

ALTER SEQUENCE availability_id_seq OWNED BY availability.id;


--
-- Name: availability_promotion_group; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE availability_promotion_group (
    availability_id integer NOT NULL,
    promotion_group_id integer NOT NULL
);


ALTER TABLE shipping.availability_promotion_group OWNER TO sos;

--
-- Name: availability_restriction; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE availability_restriction (
    id integer NOT NULL,
    attribute_id integer NOT NULL,
    availability_id integer NOT NULL
);


ALTER TABLE shipping.availability_restriction OWNER TO sos;

--
-- Name: availability_restriction_id_seq; Type: SEQUENCE; Schema: shipping; Owner: sos
--

CREATE SEQUENCE availability_restriction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shipping.availability_restriction_id_seq OWNER TO sos;

--
-- Name: availability_restriction_id_seq; Type: SEQUENCE OWNED BY; Schema: shipping; Owner: sos
--

ALTER SEQUENCE availability_restriction_id_seq OWNED BY availability_restriction.id;


--
-- Name: country_restriction; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE country_restriction (
    attribute_id integer NOT NULL,
    country_id integer NOT NULL,
    "DC" character varying(10) NOT NULL
);


ALTER TABLE shipping.country_restriction OWNER TO sos;

--
-- Name: description; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE description (
    id integer NOT NULL,
    locale_id integer NOT NULL,
    shipping_availability_id integer NOT NULL,
    name text NOT NULL,
    title text NOT NULL,
    public_name text NOT NULL,
    public_title text NOT NULL,
    short_delivery_description text,
    long_delivery_description text,
    estimated_delivery text,
    delivery_confirmation text,
    cut_off_weekday text DEFAULT ''::text NOT NULL,
    cut_off_weekend text DEFAULT ''::text NOT NULL
);


ALTER TABLE shipping.description OWNER TO sos;

--
-- Name: description_id_seq; Type: SEQUENCE; Schema: shipping; Owner: sos
--

CREATE SEQUENCE description_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shipping.description_id_seq OWNER TO sos;

--
-- Name: description_id_seq; Type: SEQUENCE OWNED BY; Schema: shipping; Owner: sos
--

ALTER SEQUENCE description_id_seq OWNED BY description.id;


--
-- Name: division_restriction; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE division_restriction (
    attribute_id integer NOT NULL,
    division_id integer NOT NULL,
    "DC" character varying(10) NOT NULL
);


ALTER TABLE shipping.division_restriction OWNER TO sos;

--
-- Name: option; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE option (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    is_limited_availability boolean DEFAULT false NOT NULL
);


ALTER TABLE shipping.option OWNER TO sos;

--
-- Name: TABLE option; Type: COMMENT; Schema: shipping; Owner: sos
--

COMMENT ON TABLE option IS 'This table is for shipping-options.';


--
-- Name: option_id_seq; Type: SEQUENCE; Schema: shipping; Owner: sos
--

CREATE SEQUENCE option_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shipping.option_id_seq OWNER TO sos;

--
-- Name: option_id_seq; Type: SEQUENCE OWNED BY; Schema: shipping; Owner: sos
--

ALTER SEQUENCE option_id_seq OWNED BY option.id;


--
-- Name: packaging_group; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE packaging_group (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE shipping.packaging_group OWNER TO sos;

--
-- Name: packaging_group_id_seq; Type: SEQUENCE; Schema: shipping; Owner: sos
--

CREATE SEQUENCE packaging_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shipping.packaging_group_id_seq OWNER TO sos;

--
-- Name: packaging_group_id_seq; Type: SEQUENCE OWNED BY; Schema: shipping; Owner: sos
--

ALTER SEQUENCE packaging_group_id_seq OWNED BY packaging_group.id;


--
-- Name: post_code_restriction; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE post_code_restriction (
    attribute_id integer NOT NULL,
    post_code_group_id integer NOT NULL,
    "DC" character varying(10) NOT NULL
);


ALTER TABLE shipping.post_code_restriction OWNER TO sos;

--
-- Name: promotion_group; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE promotion_group (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE shipping.promotion_group OWNER TO sos;

--
-- Name: promotion_group_id_seq; Type: SEQUENCE; Schema: shipping; Owner: sos
--

CREATE SEQUENCE promotion_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shipping.promotion_group_id_seq OWNER TO sos;

--
-- Name: promotion_group_id_seq; Type: SEQUENCE OWNED BY; Schema: shipping; Owner: sos
--

ALTER SEQUENCE promotion_group_id_seq OWNED BY promotion_group.id;


--
-- Name: signature_required_status; Type: TABLE; Schema: shipping; Owner: sos; Tablespace:
--

CREATE TABLE signature_required_status (
    id integer NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


ALTER TABLE shipping.signature_required_status OWNER TO sos;

--
-- Name: signature_required_status_id_seq; Type: SEQUENCE; Schema: shipping; Owner: sos
--

CREATE SEQUENCE signature_required_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shipping.signature_required_status_id_seq OWNER TO sos;

--
-- Name: signature_required_status_id_seq; Type: SEQUENCE OWNED BY; Schema: shipping; Owner: sos
--

ALTER SEQUENCE signature_required_status_id_seq OWNED BY signature_required_status.id;


SET search_path = delivery, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY event ALTER COLUMN id SET DEFAULT nextval('event_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY event_type ALTER COLUMN id SET DEFAULT nextval('event_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY file ALTER COLUMN id SET DEFAULT nextval('file_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY restriction ALTER COLUMN id SET DEFAULT nextval('restriction_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY stage ALTER COLUMN id SET DEFAULT nextval('stage_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY stage_days_to_complete ALTER COLUMN id SET DEFAULT nextval('stage_days_to_complete_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY business ALTER COLUMN id SET DEFAULT nextval('business_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY carrier ALTER COLUMN id SET DEFAULT nextval('carrier_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY country ALTER COLUMN id SET DEFAULT nextval('country_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY currency ALTER COLUMN id SET DEFAULT nextval('currency_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY dc ALTER COLUMN id SET DEFAULT nextval('dc_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY division ALTER COLUMN id SET DEFAULT nextval('division_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY language ALTER COLUMN id SET DEFAULT nextval('language_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY locale ALTER COLUMN id SET DEFAULT nextval('locale_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY post_code ALTER COLUMN id SET DEFAULT nextval('post_code_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sos
--

ALTER TABLE ONLY post_code_group ALTER COLUMN id SET DEFAULT nextval('post_code_group_id_seq'::regclass);


SET search_path = shipping, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY attribute ALTER COLUMN id SET DEFAULT nextval('attribute_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability ALTER COLUMN id SET DEFAULT nextval('availability_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability_restriction ALTER COLUMN id SET DEFAULT nextval('availability_restriction_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY description ALTER COLUMN id SET DEFAULT nextval('description_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY option ALTER COLUMN id SET DEFAULT nextval('option_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY packaging_group ALTER COLUMN id SET DEFAULT nextval('packaging_group_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY promotion_group ALTER COLUMN id SET DEFAULT nextval('promotion_group_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY signature_required_status ALTER COLUMN id SET DEFAULT nextval('signature_required_status_id_seq'::regclass);


SET search_path = delivery, pg_catalog;

--
-- Data for Name: event; Type: TABLE DATA; Schema: delivery; Owner: sos
--



--
-- Name: event_id_seq; Type: SEQUENCE SET; Schema: delivery; Owner: sos
--

SELECT pg_catalog.setval('event_id_seq', 1, false);


--
-- Data for Name: event_type; Type: TABLE DATA; Schema: delivery; Owner: sos
--

INSERT INTO event_type VALUES (1, 'Delivery Attempted', 'ATTEMPTED');
INSERT INTO event_type VALUES (2, 'Delivery Completed', 'COMPLETED');


--
-- Name: event_type_id_seq; Type: SEQUENCE SET; Schema: delivery; Owner: sos
--

SELECT pg_catalog.setval('event_type_id_seq', 2, true);


--
-- Data for Name: file; Type: TABLE DATA; Schema: delivery; Owner: sos
--



--
-- Name: file_id_seq; Type: SEQUENCE SET; Schema: delivery; Owner: sos
--

SELECT pg_catalog.setval('file_id_seq', 1, false);


--
-- Data for Name: restriction; Type: TABLE DATA; Schema: delivery; Owner: sos
--



--
-- Name: restriction_id_seq; Type: SEQUENCE SET; Schema: delivery; Owner: sos
--

SELECT pg_catalog.setval('restriction_id_seq', 1, false);


--
-- Data for Name: stage; Type: TABLE DATA; Schema: delivery; Owner: sos
--

INSERT INTO stage VALUES (1, 'Dispatch', 'dispatch', 1);
INSERT INTO stage VALUES (2, 'Transit', 'transit', 2);
INSERT INTO stage VALUES (3, 'Delivery', 'delivery', 3);


--
-- Data for Name: stage_days_to_complete; Type: TABLE DATA; Schema: delivery; Owner: sos
--



--
-- Name: stage_days_to_complete_id_seq; Type: SEQUENCE SET; Schema: delivery; Owner: sos
--

SELECT pg_catalog.setval('stage_days_to_complete_id_seq', 1, false);


--
-- Name: stage_id_seq; Type: SEQUENCE SET; Schema: delivery; Owner: sos
--

SELECT pg_catalog.setval('stage_id_seq', 3, true);


SET search_path = public, pg_catalog;

--
-- Data for Name: business; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO business VALUES (1, 'NET-A-PORTER.COM', 'NAP');
INSERT INTO business VALUES (2, 'MRPORTER.COM', 'MRP');
INSERT INTO business VALUES (3, 'theOutnet.com', 'TON');
INSERT INTO business VALUES (4, 'JIMMYCHOO.COM', 'JCH');


--
-- Name: business_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('business_id_seq', 4, true);


--
-- Data for Name: carrier; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO carrier VALUES (1, 'DHL', 'DHL');
INSERT INTO carrier VALUES (2, 'UPS', 'UPS');
INSERT INTO carrier VALUES (3, 'NAP', 'NAP');


--
-- Name: carrier_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('carrier_id_seq', 3, true);


--
-- Data for Name: country; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO country VALUES (1, 'United States', 'US');
INSERT INTO country VALUES (2, 'Oman', 'OM');
INSERT INTO country VALUES (3, 'Serbia', 'RS');
INSERT INTO country VALUES (4, 'Montenegro', 'ME');
INSERT INTO country VALUES (5, 'Qatar', 'QA');
INSERT INTO country VALUES (6, 'Saudi Arabia', 'SA');
INSERT INTO country VALUES (7, 'Switzerland', 'CH');
INSERT INTO country VALUES (8, 'United Arab Emirates', 'AE');
INSERT INTO country VALUES (9, 'New Zealand', 'NZ');
INSERT INTO country VALUES (10, 'Philippines', 'PH');
INSERT INTO country VALUES (11, 'Romania', 'RO');
INSERT INTO country VALUES (12, 'Jordan', 'JO');
INSERT INTO country VALUES (13, 'Canada', 'CA');
INSERT INTO country VALUES (14, 'Singapore', 'SG');
INSERT INTO country VALUES (15, 'Malaysia', 'MY');
INSERT INTO country VALUES (16, 'French Polynesia', 'PF');
INSERT INTO country VALUES (17, 'Taiwan ROC', 'TW');
INSERT INTO country VALUES (18, 'Ukraine', 'UA');
INSERT INTO country VALUES (19, 'British Virgin Islands', 'VG');
INSERT INTO country VALUES (20, 'Vietnam', 'VN');
INSERT INTO country VALUES (21, 'Andorra', 'AD');
INSERT INTO country VALUES (22, 'Austria', 'AT');
INSERT INTO country VALUES (23, 'Kazakhstan', 'KZ');
INSERT INTO country VALUES (24, 'Anguilla', 'AI');
INSERT INTO country VALUES (25, 'Albania', 'AL');
INSERT INTO country VALUES (26, 'Netherlands Antilles', 'AN');
INSERT INTO country VALUES (27, 'Aruba', 'AW');
INSERT INTO country VALUES (28, 'Bangladesh', 'BD');
INSERT INTO country VALUES (29, 'Bolivia', 'BO');
INSERT INTO country VALUES (30, 'Bhutan', 'BT');
INSERT INTO country VALUES (31, 'Botswana', 'BW');
INSERT INTO country VALUES (32, 'Belize', 'BZ');
INSERT INTO country VALUES (33, 'Cook Islands', 'CK');
INSERT INTO country VALUES (34, 'Colombia', 'CO');
INSERT INTO country VALUES (35, 'Cape Verde Islands', 'CV');
INSERT INTO country VALUES (36, 'Dominica', 'DM');
INSERT INTO country VALUES (37, 'Algeria', 'DZ');
INSERT INTO country VALUES (38, 'Ecuador', 'EC');
INSERT INTO country VALUES (39, 'Fiji', 'FJ');
INSERT INTO country VALUES (40, 'Falkland Islands', 'FK');
INSERT INTO country VALUES (41, 'Faroe Islands', 'FO');
INSERT INTO country VALUES (42, 'Gabon', 'GA');
INSERT INTO country VALUES (43, 'Grenada', 'GD');
INSERT INTO country VALUES (44, 'French Guiana', 'GF');
INSERT INTO country VALUES (45, 'Gambia', 'GM');
INSERT INTO country VALUES (46, 'Guatemala', 'GT');
INSERT INTO country VALUES (47, 'Guam', 'GU');
INSERT INTO country VALUES (48, 'Honduras', 'HN');
INSERT INTO country VALUES (49, 'Jamaica', 'JM');
INSERT INTO country VALUES (50, 'Cambodia', 'KH');
INSERT INTO country VALUES (51, 'Comoros Islands', 'KM');
INSERT INTO country VALUES (52, 'Saint Kitts and Nevis', 'KN');
INSERT INTO country VALUES (53, 'Laos', 'LA');
INSERT INTO country VALUES (54, 'Lesotho', 'LS');
INSERT INTO country VALUES (55, 'Mongolia', 'MN');
INSERT INTO country VALUES (56, 'Martinique', 'MQ');
INSERT INTO country VALUES (57, 'Montserrat', 'MS');
INSERT INTO country VALUES (58, 'Maldives', 'MV');
INSERT INTO country VALUES (59, 'Malawi', 'MW');
INSERT INTO country VALUES (60, 'Namibia', 'NA');
INSERT INTO country VALUES (61, 'Belgium', 'BE');
INSERT INTO country VALUES (62, 'Kenya', 'KE');
INSERT INTO country VALUES (63, 'Cyprus', 'CY');
INSERT INTO country VALUES (64, 'Czech Republic', 'CZ');
INSERT INTO country VALUES (65, 'Germany', 'DE');
INSERT INTO country VALUES (66, 'Denmark', 'DK');
INSERT INTO country VALUES (67, 'Estonia', 'EE');
INSERT INTO country VALUES (68, 'Nicaragua', 'NI');
INSERT INTO country VALUES (69, 'Nepal', 'NP');
INSERT INTO country VALUES (70, 'Panama', 'PA');
INSERT INTO country VALUES (71, 'Peru', 'PE');
INSERT INTO country VALUES (72, 'Paraguay', 'PY');
INSERT INTO country VALUES (73, 'New Caledonia', 'NC');
INSERT INTO country VALUES (74, 'Seychelles', 'SC');
INSERT INTO country VALUES (75, 'Sierra Leone', 'SL');
INSERT INTO country VALUES (76, 'Suriname', 'SR');
INSERT INTO country VALUES (77, 'Sao Tome and Principe', 'ST');
INSERT INTO country VALUES (78, 'El Salvador', 'SV');
INSERT INTO country VALUES (79, 'Swaziland', 'SZ');
INSERT INTO country VALUES (80, 'Turks and Caicos Islands', 'TC');
INSERT INTO country VALUES (81, 'Togo', 'TG');
INSERT INTO country VALUES (82, 'US Virgin Islands', 'VI');
INSERT INTO country VALUES (83, 'Tonga', 'TO');
INSERT INTO country VALUES (84, 'Trinidad and Tobago', 'TT');
INSERT INTO country VALUES (85, 'Tuvalu', 'TV');
INSERT INTO country VALUES (86, 'Tanzania', 'TZ');
INSERT INTO country VALUES (87, 'Saint Vincent and the Grenadines', 'VC');
INSERT INTO country VALUES (88, 'Vanuatu', 'VU');
INSERT INTO country VALUES (89, 'Samoa', 'WS');
INSERT INTO country VALUES (90, 'Saipan', 'MP');
INSERT INTO country VALUES (91, 'Brazil', 'BR');
INSERT INTO country VALUES (92, 'North Korea', 'KP');
INSERT INTO country VALUES (93, 'Belarus', 'BY');
INSERT INTO country VALUES (94, 'United Kingdom', 'GB');
INSERT INTO country VALUES (95, 'Spain', 'ES');
INSERT INTO country VALUES (96, 'France', 'FR');
INSERT INTO country VALUES (97, 'Greece', 'GR');
INSERT INTO country VALUES (98, 'Hungary', 'HU');
INSERT INTO country VALUES (99, 'Ireland', 'IE');
INSERT INTO country VALUES (100, 'Italy', 'IT');
INSERT INTO country VALUES (101, 'Lithuania', 'LT');
INSERT INTO country VALUES (102, 'Luxembourg', 'LU');
INSERT INTO country VALUES (103, 'Latvia', 'LV');
INSERT INTO country VALUES (104, 'Monaco', 'MC');
INSERT INTO country VALUES (105, 'Malta', 'MT');
INSERT INTO country VALUES (106, 'Netherlands', 'NL');
INSERT INTO country VALUES (107, 'Poland', 'PL');
INSERT INTO country VALUES (108, 'Portugal', 'PT');
INSERT INTO country VALUES (109, 'Sweden', 'SE');
INSERT INTO country VALUES (110, 'Slovenia', 'SI');
INSERT INTO country VALUES (111, 'Slovakia', 'SK');
INSERT INTO country VALUES (112, 'Guyana', 'GY');
INSERT INTO country VALUES (113, 'Egypt', 'EG');
INSERT INTO country VALUES (114, 'Madagascar', 'MG');
INSERT INTO country VALUES (115, 'Angola', 'AO');
INSERT INTO country VALUES (116, 'Cameroon', 'CM');
INSERT INTO country VALUES (117, 'Tunisia', 'TN');
INSERT INTO country VALUES (118, 'Moldova', 'MD');
INSERT INTO country VALUES (119, 'Uruguay', 'UY');
INSERT INTO country VALUES (120, 'Liberia', 'LR');
INSERT INTO country VALUES (121, 'Pakistan', 'PK');
INSERT INTO country VALUES (122, 'San Marino', 'SM');
INSERT INTO country VALUES (123, 'Senegal', 'SN');
INSERT INTO country VALUES (124, 'Bahrain', 'BH');
INSERT INTO country VALUES (125, 'Antigua and Barbuda', 'AG');
INSERT INTO country VALUES (126, 'South Korea', 'KR');
INSERT INTO country VALUES (127, 'Bosnia-Herzegovina', 'BA');
INSERT INTO country VALUES (128, 'Barbados', 'BB');
INSERT INTO country VALUES (129, 'Puerto Rico', 'PR');
INSERT INTO country VALUES (130, 'Costa Rica', 'CR');
INSERT INTO country VALUES (131, 'Bermuda', 'BM');
INSERT INTO country VALUES (132, 'Thailand', 'TH');
INSERT INTO country VALUES (133, 'Bahamas', 'BS');
INSERT INTO country VALUES (134, 'Venezuela', 'VE');
INSERT INTO country VALUES (135, 'Argentina', 'AR');
INSERT INTO country VALUES (136, 'Azerbaijan', 'AZ');
INSERT INTO country VALUES (137, 'Dominican Republic', 'DO');
INSERT INTO country VALUES (138, 'Brunei', 'BN');
INSERT INTO country VALUES (139, 'Greenland', 'GL');
INSERT INTO country VALUES (140, 'Guadeloupe', 'GP');
INSERT INTO country VALUES (141, 'Indonesia', 'ID');
INSERT INTO country VALUES (142, 'Georgia', 'GE');
INSERT INTO country VALUES (143, 'Russia', 'RU');
INSERT INTO country VALUES (144, 'Cayman Islands', 'KY');
INSERT INTO country VALUES (145, 'Liechtenstein', 'LI');
INSERT INTO country VALUES (146, 'Sri Lanka', 'LK');
INSERT INTO country VALUES (147, 'Morocco', 'MA');
INSERT INTO country VALUES (148, 'Macedonia', 'MK');
INSERT INTO country VALUES (149, 'Mexico', 'MX');
INSERT INTO country VALUES (150, 'China', 'CN');
INSERT INTO country VALUES (151, 'Mozambique', 'MZ');
INSERT INTO country VALUES (152, 'Ethiopia', 'ET');
INSERT INTO country VALUES (153, 'Macau', 'MO');
INSERT INTO country VALUES (154, 'East Timor', 'TL');
INSERT INTO country VALUES (155, 'Papua New Guinea', 'PG');
INSERT INTO country VALUES (156, 'Canary Islands', 'IC');
INSERT INTO country VALUES (157, 'Jersey', 'JE');
INSERT INTO country VALUES (158, 'Guernsey', 'GG');
INSERT INTO country VALUES (159, 'Yemen', 'YE');
INSERT INTO country VALUES (160, 'St Barthelemy', 'BL');
INSERT INTO country VALUES (161, 'Ghana', 'GH');
INSERT INTO country VALUES (162, 'Syria', 'SY');
INSERT INTO country VALUES (163, 'Haiti', 'HT');
INSERT INTO country VALUES (164, 'Bulgaria', 'BG');
INSERT INTO country VALUES (165, 'Armenia', 'AM');
INSERT INTO country VALUES (166, 'American Samoa', 'AS');
INSERT INTO country VALUES (167, 'Federated States of Micronesia', 'FM');
INSERT INTO country VALUES (168, 'Marshall Islands', 'MH');
INSERT INTO country VALUES (169, 'Palau', 'PW');
INSERT INTO country VALUES (170, 'Reunion Island', 'RE');
INSERT INTO country VALUES (171, 'Solomon Islands', 'SB');
INSERT INTO country VALUES (172, 'Uganda', 'UG');
INSERT INTO country VALUES (173, 'India', 'IN');
INSERT INTO country VALUES (174, 'South Africa', 'ZA');
INSERT INTO country VALUES (175, 'Gibraltar', 'GI');
INSERT INTO country VALUES (176, 'Saint Lucia', 'LC');
INSERT INTO country VALUES (177, 'Finland', 'FI');
INSERT INTO country VALUES (178, 'Norway', 'NO');
INSERT INTO country VALUES (179, 'Mauritius', 'MU');
INSERT INTO country VALUES (180, 'Turkey', 'TR');
INSERT INTO country VALUES (181, 'Israel', 'IL');
INSERT INTO country VALUES (182, 'Iceland', 'IS');
INSERT INTO country VALUES (183, 'Japan', 'JP');
INSERT INTO country VALUES (184, 'Chile', 'CL');
INSERT INTO country VALUES (185, 'Lebanon', 'LB');
INSERT INTO country VALUES (186, 'Kuwait', 'KW');
INSERT INTO country VALUES (187, 'Hong Kong', 'HK');
INSERT INTO country VALUES (188, 'Australia', 'AU');
INSERT INTO country VALUES (189, 'Croatia', 'HR');
INSERT INTO country VALUES (190, 'Curaçao', 'CW');


--
-- Name: country_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('country_id_seq', 190, true);


--
-- Data for Name: currency; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO currency VALUES (1, 'United Kingdom Pound', 'GBP');
INSERT INTO currency VALUES (2, 'United States Dollar', 'USD');
INSERT INTO currency VALUES (3, 'Euro Member Countries', 'EUR');
INSERT INTO currency VALUES (4, 'Australia Dollar', 'AUD');
INSERT INTO currency VALUES (5, 'Japan Yen', 'JPY');
INSERT INTO currency VALUES (6, 'Hong Kong Dollar', 'HKD');
INSERT INTO currency VALUES (7, 'China Yuan Renminbi', 'CNY');
INSERT INTO currency VALUES (8, 'Korea (South) Won', 'KRW');


--
-- Name: currency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('currency_id_seq', 8, true);


--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO databasechangelog VALUES ('1', 'g.ceccarelli', 'db/sos/patches/00000-ALL-base_schema.sql', '2016-01-07 15:59:59.482719+00', 1, 'EXECUTED', '7:8a53a159e7b6c22cfe65fb9d6d4f922f', 'sql', '', '1', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'g.ceccarelli', 'db/sos/updates_dc1.xml', '2016-01-07 15:59:59.554123+00', 2, 'EXECUTED', '7:191f6e38d86904d3d1e7b4ee3c5a54db', 'tagDatabase', '', '1', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'a.todd', 'db/sos/patches/00001-ALL-SHIP-43-countries.sql', '2016-01-07 15:59:59.714079+00', 3, 'EXECUTED', '7:5c1b3ba45bfe7052ab72e8e194ce9359', 'sql', '', NULL, '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'a.todd', 'db/sos/patches/00002-ALL-SHIP-43-currencies.sql', '2016-01-07 15:59:59.792248+00', 4, 'EXECUTED', '7:7ddfe8faf20e137d197fa223dfa1c07e', 'sql', '', '2', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 15:59:59.828532+00', 5, 'EXECUTED', '7:2acf12b84172118f68e773a302a6ac1c', 'tagDatabase', '', '2', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'n.onyiah', 'db/sos/patches/00003-ALL-SHIP-326-restrictions.sql', '2016-01-07 15:59:59.910977+00', 6, 'EXECUTED', '7:725331f5ea3b0dbabd7a807d53969bc7', 'sql', '', NULL, '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'n.onyiah', 'db/sos/patches/00003-DC1-SHIP-326-restrictions.sql', '2016-01-07 15:59:59.952783+00', 7, 'EXECUTED', '7:df663ab89f45d024252d52df3f04a4a7', 'sql', '', '3', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'n.onyiah', 'db/sos/updates_dc1.xml', '2016-01-07 15:59:59.971861+00', 8, 'EXECUTED', '7:56cf0ae4f48ce843eca77aba23f87827', 'tagDatabase', '', '3', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'a.todd', 'db/sos/patches/00004-ALL-SHIP-371-shipping-options.sql', '2016-01-07 16:00:00.038788+00', 9, 'EXECUTED', '7:91976eade1a090f998725b08f789a452', 'sql', '', NULL, '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'a.todd', 'db/sos/patches/00004-DC1-SHIP-371-shipping-options.sql', '2016-01-07 16:00:00.080477+00', 10, 'EXECUTED', '7:e85b8d1780479820b23c4a9a0d22b712', 'sql', '', '4', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.116707+00', 11, 'EXECUTED', '7:89e1f0f877aed38673b80404c7aeb0a4', 'tagDatabase', '', '4', '${project.version}');
INSERT INTO databasechangelog VALUES ('3', 'a.todd', 'db/sos/patches/00005-ALL-SHIP-368-delivery-restrictions.sql', '2016-01-07 16:00:00.184377+00', 12, 'EXECUTED', '7:5ad616246accd07cdabfdfffd626d709', 'sql', '', '5', '${project.version}');
INSERT INTO databasechangelog VALUES ('3', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.224382+00', 13, 'EXECUTED', '7:b2fe73bfe42b931f7250c3fd77cb4a93', 'tagDatabase', '', '5', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'n.onyiah', 'db/sos/patches/00006-ALL-SHIP-369-shipping-description.sql', '2016-01-07 16:00:00.298488+00', 14, 'EXECUTED', '7:5f8a9677d5886f4b0e6b193de0561483', 'sql', '', '6', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'n.onyiah', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.341334+00', 15, 'EXECUTED', '7:88460bc60652170cd58fa7356674a8d6', 'tagDatabase', '', '6', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'r.hill', 'db/sos/patches/00007-ALL-SHIP-374-add-locales.sql', '2016-01-07 16:00:00.393198+00', 16, 'EXECUTED', '7:f56da19904a94920b31c961d0b0e9240', 'sql', '', '7', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'r.hill', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.422029+00', 17, 'EXECUTED', '7:fe83337ab925bd8f9894618d8c55223a', 'tagDatabase', '', '7', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'j.maslen', 'db/sos/patches/00008-ALL-SHIP-559-promotion-groups.sql', '2016-01-07 16:00:00.450554+00', 18, 'EXECUTED', '7:d856fd32a03746f9c396bc819eb622ae', 'sql', '', '8', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'j.maslen', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.499611+00', 19, 'EXECUTED', '7:273ce238044a1f541e281a335adfc7cd', 'tagDatabase', '', '8', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'j.maslen', 'db/sos/patches/00009-ALL-SHIP-558-packaging-groups.sql', '2016-01-07 16:00:00.558749+00', 20, 'EXECUTED', '7:17f68d1966dcddec222da21a561b9021', 'sql', '', '9', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'j.maslen', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.59743+00', 21, 'EXECUTED', '7:970e1af6328e0dd8dfd177290d0ee46c', 'tagDatabase', '', '9', '${project.version}');
INSERT INTO databasechangelog VALUES ('4', 'a.todd', 'db/sos/patches/00010-ALL-SHIP-375-signature-required.sql', '2016-01-07 16:00:00.644158+00', 22, 'EXECUTED', '7:39ee2b5df4cdc57d487da7be921a4e02', 'sql', '', '10', '${project.version}');
INSERT INTO databasechangelog VALUES ('4', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.685349+00', 23, 'EXECUTED', '7:ac89a69c55e7d3794c69c4423515ac7c', 'tagDatabase', '', '10', '${project.version}');
INSERT INTO databasechangelog VALUES ('5', 'a.todd', 'db/sos/patches/00011-ALL-SHIP-373-nomday.sql', '2016-01-07 16:00:00.737468+00', 24, 'EXECUTED', '7:6c8587a0fb6cb98d8c8c9ff2c75ded6b', 'sql', '', '11', '${project.version}');
INSERT INTO databasechangelog VALUES ('5', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.767831+00', 25, 'EXECUTED', '7:8e857843f74726749a79dd3d9c87d37f', 'tagDatabase', '', '11', '${project.version}');
INSERT INTO databasechangelog VALUES ('raw', 'includeAll', 'db/sos/patches/00006-ALL-SHIP-554-division-postcode-options.sql', '2016-01-07 16:00:00.811843+00', 26, 'EXECUTED', '7:2af113d0759bd9fd5e5b0dd695f9d0ba', 'sql', '', '12', '${project.version}');
INSERT INTO databasechangelog VALUES ('3', 'n.onyiah', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.838415+00', 27, 'EXECUTED', '7:fce0da38c0cfa24aadc7ea05db0550b3', 'tagDatabase', '', '12', '${project.version}');
INSERT INTO databasechangelog VALUES ('6', 'a.todd', 'db/sos/patches/00012-ALL-NOJIRA-extra_divisions.sql', '2016-01-07 16:00:00.894608+00', 28, 'EXECUTED', '7:abb6b127a5552d118bb5b9f44febcffd', 'sql', '', '13', '${project.version}');
INSERT INTO databasechangelog VALUES ('6', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:00.950894+00', 29, 'EXECUTED', '7:cd39e5b82f739aee22f132effc6ba18d', 'tagDatabase', '', '13', '${project.version}');
INSERT INTO databasechangelog VALUES ('7', 'a.todd', 'db/sos/patches/00013-ALL-SHIP-554-limited_availability_options.sql', '2016-01-07 16:00:00.996917+00', 30, 'EXECUTED', '7:bc28fe9bf80146f4c687542408ba05e6', 'sql', '', '14', '${project.version}');
INSERT INTO databasechangelog VALUES ('7', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.03528+00', 31, 'EXECUTED', '7:5bed4c7352849d67a40001d134691697', 'tagDatabase', '', '14', '${project.version}');
INSERT INTO databasechangelog VALUES ('8', 'a.todd', 'db/sos/patches/00014-ALL-SHIP-554-anytime.sql', '2016-01-07 16:00:01.078814+00', 32, 'EXECUTED', '7:aade5ae9375694ceadd6427b7dac20fb', 'sql', '', '15', '${project.version}');
INSERT INTO databasechangelog VALUES ('8', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.1297+00', 33, 'EXECUTED', '7:134e0fb34c4e8f59f7da3fa0bb8fa34b', 'tagDatabase', '', '15', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'r.hill', 'db/sos/patches/00013-ALL-SHIP-560-availability-promo-import-groups.sql', '2016-01-07 16:00:01.173869+00', 34, 'EXECUTED', '7:1dbb6d01d6eb457a7484e3bd2e3a56f1', 'sql', '', '16', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'r.hill', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.204577+00', 35, 'EXECUTED', '7:b913cc71a23109b8dfb9cf1b5e731870', 'tagDatabase', '', '16', '${project.version}');
INSERT INTO databasechangelog VALUES ('9\', 'a.todd', 'db/sos/patches/00016-ALL-SHIP-706.sql', '2016-01-07 16:00:01.265011+00', 36, 'EXECUTED', '7:bc9392a982398d06ed39a216a471f71c', 'sql', '', '17', '${project.version}');
INSERT INTO databasechangelog VALUES ('9', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.308829+00', 37, 'EXECUTED', '7:636fc206652e1e433cec21be833b5868', 'tagDatabase', '', '17', '${project.version}');
INSERT INTO databasechangelog VALUES ('7', 'a.todd', 'db/sos/patches/00017-ALL-test.sql', '2016-01-07 16:00:01.348848+00', 38, 'EXECUTED', '7:6ff6022fa72aa8255f05e86a2e067ab7', 'sql', '', '18', '${project.version}');
INSERT INTO databasechangelog VALUES ('10', 'a.todd', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.3673+00', 39, 'EXECUTED', '7:c3a24511becbfe8f4089ab0bf5eb3f13', 'tagDatabase', '', '18', '${project.version}');
INSERT INTO databasechangelog VALUES ('raw', 'includeAll', 'db/sos/patches/00018-DC1-ship-761-restrict_hazmat_lq_for_jersey_and_guernsey.sql', '2016-01-07 16:00:01.38286+00', 40, 'EXECUTED', '7:85c7cc6f9ce365d2ee15c7e28e47a4f0', 'sql', '', '19', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'p.singh', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.401963+00', 41, 'EXECUTED', '7:6c17e4b72614ceb8f848f6e9e878d847', 'tagDatabase', '', '19', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'm.iclodean', 'db/sos/patches/00019-ALL-SHIP-908.sql', '2016-01-07 16:00:01.430497+00', 42, 'EXECUTED', '7:90a8c7d3c70187aef5e9730445f74be0', 'sql', '', '20', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'm.iclodean', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.45384+00', 43, 'EXECUTED', '7:0d13041bd52b904083007a2fa49b3df8', 'tagDatabase', '', '20', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'm.iclodean', 'db/sos/patches/00020-DC1-ship-1027.sql', '2016-01-07 16:00:01.487651+00', 44, 'EXECUTED', '7:2a0559dd61385b70fdfae08b90058ec7', 'sql', '', '21', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'm.iclodean', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.514316+00', 45, 'EXECUTED', '7:b58e8b6fc2a30829479e1f3eed9d771d', 'tagDatabase', '', '21', '${project.version}');
INSERT INTO databasechangelog VALUES ('raw', 'includeAll', 'db/sos/patches/00021-ALL-ship-1071_add_new_description_fields.sql', '2016-01-07 16:00:01.550183+00', 46, 'EXECUTED', '7:a46501dbcb86327419fb4a9dee1f9c57', 'sql', '', '22', '${project.version}');
INSERT INTO databasechangelog VALUES ('2', 'p.singh', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.564773+00', 47, 'EXECUTED', '7:70fa3404491794de8837bd1a87769e28', 'tagDatabase', '', '22', '${project.version}');
INSERT INTO databasechangelog VALUES ('3', 'm.iclodean', 'db/sos/patches/00022-ALL-SHIP-1062-availability-attribute-retrictions.sql', '2016-01-07 16:00:01.588996+00', 48, 'EXECUTED', '7:edbfcdd6799d5c49c11d9f1a58b7b093', 'sql', '', '23', '${project.version}');
INSERT INTO databasechangelog VALUES ('3', 'm.iclodean', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.606324+00', 49, 'EXECUTED', '7:b4c8eb9f24ea4cbeb57373fff8002bc5', 'tagDatabase', '', '23', '${project.version}');
INSERT INTO databasechangelog VALUES ('4', 'm.iclodean', 'db/sos/patches/00023-DC1-SHIP-1062-add_availability_attribute_restrictions.sql', '2016-01-07 16:00:01.632494+00', 50, 'EXECUTED', '7:393393f16a3dd1f19aa14052a3ce23fd', 'sql', '', '24', '${project.version}');
INSERT INTO databasechangelog VALUES ('4', 'm.iclodean', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.66146+00', 51, 'EXECUTED', '7:ff27b447d2b70b7ef523653350270540', 'tagDatabase', '', '24', '${project.version}');
INSERT INTO databasechangelog VALUES ('raw', 'includeAll', 'db/sos/patches/00024-Add-DC-Column.sql', '2016-01-07 16:00:01.733084+00', 52, 'EXECUTED', '7:ffe526983c2e85f221268b21d0fbadc9', 'sql', '', '25', '${project.version}');
INSERT INTO databasechangelog VALUES ('1', 'm.esquerra', 'db/sos/updates_dc1.xml', '2016-01-07 16:00:01.761501+00', 53, 'EXECUTED', '7:bca951824b82578fd334b67760b5634a', 'tagDatabase', '', '25', '${project.version}');


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO databasechangeloglock VALUES (1, false, NULL, NULL);


--
-- Data for Name: dc; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO dc VALUES (1, 'DC1', 'Distribution Centre 1');
INSERT INTO dc VALUES (2, 'DC2', 'Distribution Centre 2');
INSERT INTO dc VALUES (3, 'DC3', 'Distribution Centre 3');


--
-- Name: dc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('dc_id_seq', 3, true);


--
-- Data for Name: division; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO division VALUES (1, 'Alabama', 'AL', 1);
INSERT INTO division VALUES (2, 'Alaska', 'AK', 1);
INSERT INTO division VALUES (3, 'Arizona', 'AZ', 1);
INSERT INTO division VALUES (4, 'Arkansas', 'AR', 1);
INSERT INTO division VALUES (5, 'Colorado', 'CO', 1);
INSERT INTO division VALUES (6, 'Connecticut', 'CT', 1);
INSERT INTO division VALUES (7, 'Delaware', 'DE', 1);
INSERT INTO division VALUES (8, 'Florida', 'FL', 1);
INSERT INTO division VALUES (9, 'Georgia', 'GA', 1);
INSERT INTO division VALUES (10, 'Hawaii', 'HI', 1);
INSERT INTO division VALUES (11, 'Idaho', 'ID', 1);
INSERT INTO division VALUES (12, 'Illinois', 'IL', 1);
INSERT INTO division VALUES (13, 'Indiana', 'IN', 1);
INSERT INTO division VALUES (14, 'Iowa', 'IA', 1);
INSERT INTO division VALUES (15, 'Kansas', 'KS', 1);
INSERT INTO division VALUES (16, 'Kentucky', 'KY', 1);
INSERT INTO division VALUES (17, 'Louisiana', 'LA', 1);
INSERT INTO division VALUES (18, 'Maine', 'ME', 1);
INSERT INTO division VALUES (19, 'Maryland', 'MD', 1);
INSERT INTO division VALUES (20, 'Massachusetts', 'MA', 1);
INSERT INTO division VALUES (21, 'Michigan', 'MI', 1);
INSERT INTO division VALUES (22, 'Minnesota', 'MN', 1);
INSERT INTO division VALUES (23, 'Mississippi', 'MS', 1);
INSERT INTO division VALUES (24, 'Missouri', 'MO', 1);
INSERT INTO division VALUES (25, 'Montana', 'MT', 1);
INSERT INTO division VALUES (26, 'Nebraska', 'NE', 1);
INSERT INTO division VALUES (27, 'Nevada', 'NV', 1);
INSERT INTO division VALUES (28, 'New Hampshire', 'NH', 1);
INSERT INTO division VALUES (29, 'New Jersey', 'NJ', 1);
INSERT INTO division VALUES (30, 'New Mexico', 'NM', 1);
INSERT INTO division VALUES (31, 'New York', 'NY', 1);
INSERT INTO division VALUES (32, 'North Carolina', 'NC', 1);
INSERT INTO division VALUES (33, 'North Dakota', 'ND', 1);
INSERT INTO division VALUES (34, 'Ohio', 'OH', 1);
INSERT INTO division VALUES (35, 'Oklahoma', 'OK', 1);
INSERT INTO division VALUES (36, 'Oregon', 'OR', 1);
INSERT INTO division VALUES (37, 'Pennsylvania', 'PA', 1);
INSERT INTO division VALUES (38, 'Rhode Island', 'RI', 1);
INSERT INTO division VALUES (39, 'South Carolina', 'SC', 1);
INSERT INTO division VALUES (40, 'South Dakota', 'SD', 1);
INSERT INTO division VALUES (41, 'Tennessee', 'TN', 1);
INSERT INTO division VALUES (42, 'Texas', 'TX', 1);
INSERT INTO division VALUES (43, 'Utah', 'UT', 1);
INSERT INTO division VALUES (44, 'Vermont', 'VT', 1);
INSERT INTO division VALUES (45, 'Virginia', 'VA', 1);
INSERT INTO division VALUES (46, 'Washington', 'WA', 1);
INSERT INTO division VALUES (47, 'West Virginia', 'WV', 1);
INSERT INTO division VALUES (48, 'Wisconsin', 'WI', 1);
INSERT INTO division VALUES (49, 'Wyoming', 'WY', 1);
INSERT INTO division VALUES (50, 'American Samoa', 'AS', 1);
INSERT INTO division VALUES (51, 'District of Columbia', 'DC', 1);
INSERT INTO division VALUES (52, 'Marshall Islands', 'MH', 1);
INSERT INTO division VALUES (53, 'Micronesia', 'FM', 1);
INSERT INTO division VALUES (54, 'Northern Marianas', 'MP', 1);
INSERT INTO division VALUES (55, 'Palau', 'PW', 1);
INSERT INTO division VALUES (56, 'Virgin Islands', 'VI', 1);
INSERT INTO division VALUES (57, 'Aberdeen', 'Aberdeen', 187);
INSERT INTO division VALUES (58, 'Admiralty', 'Admiralty', 187);
INSERT INTO division VALUES (59, 'Ap Lei Chau', 'Ap Lei Chau', 187);
INSERT INTO division VALUES (60, 'Causeway Bay', 'Causeway Bay', 187);
INSERT INTO division VALUES (61, 'Central', 'Central', 187);
INSERT INTO division VALUES (62, 'Chai Wan', 'Chai Wan', 187);
INSERT INTO division VALUES (63, 'Cyberport', 'Cyberport', 187);
INSERT INTO division VALUES (64, 'Deep Water Bay', 'Deep Water Bay', 187);
INSERT INTO division VALUES (65, 'Fortress Hill', 'Fortress Hill', 187);
INSERT INTO division VALUES (66, 'Happy Valley', 'Happy Valley', 187);
INSERT INTO division VALUES (67, 'Heng Fa Chuen', 'Heng Fa Chuen', 187);
INSERT INTO division VALUES (68, 'Kennedy Town', 'Kennedy Town', 187);
INSERT INTO division VALUES (69, 'Mid-Levels', 'Mid-Levels', 187);
INSERT INTO division VALUES (70, 'North Point', 'North Point', 187);
INSERT INTO division VALUES (71, 'Pok Fu Lam', 'Pok Fu Lam', 187);
INSERT INTO division VALUES (72, 'Quarry Bay', 'Quarry Bay', 187);
INSERT INTO division VALUES (73, 'Repulse Bay', 'Repulse Bay', 187);
INSERT INTO division VALUES (74, 'Sai Wan Ho', 'Sai Wan Ho', 187);
INSERT INTO division VALUES (75, 'Sai Ying Pun', 'Sai Ying Pun', 187);
INSERT INTO division VALUES (76, 'Shau Kei Wan', 'Shau Kei Wan', 187);
INSERT INTO division VALUES (77, 'Shek O', 'Shek O', 187);
INSERT INTO division VALUES (78, 'Sheung Wan', 'Sheung Wan', 187);
INSERT INTO division VALUES (79, 'Shouson Hill', 'Shouson Hill', 187);
INSERT INTO division VALUES (80, 'Stanley', 'Stanley', 187);
INSERT INTO division VALUES (81, 'Stubbs Road', 'Stubbs Road', 187);
INSERT INTO division VALUES (82, 'Tai Hang', 'Tai Hang', 187);
INSERT INTO division VALUES (83, 'Tai Koo', 'Tai Koo', 187);
INSERT INTO division VALUES (84, 'The Peak', 'The Peak', 187);
INSERT INTO division VALUES (85, 'Tin Hau', 'Tin Hau', 187);
INSERT INTO division VALUES (86, 'Wan Chai', 'Wan Chai', 187);
INSERT INTO division VALUES (87, 'Wong Chuk Hang', 'Wong Chuk Hang', 187);
INSERT INTO division VALUES (88, 'Cheung Sha Wan', 'Cheung Sha Wan', 187);
INSERT INTO division VALUES (89, 'Choi Hung', 'Choi Hung', 187);
INSERT INTO division VALUES (90, 'Choi Wan', 'Choi Wan', 187);
INSERT INTO division VALUES (91, 'Diamond Hill', 'Diamond Hill', 187);
INSERT INTO division VALUES (92, 'Ho Man Tin', 'Ho Man Tin', 187);
INSERT INTO division VALUES (93, 'Hung Hom', 'Hung Hom', 187);
INSERT INTO division VALUES (94, 'Jordan', 'Jordan', 187);
INSERT INTO division VALUES (95, 'Kowloon Bay', 'Kowloon Bay', 187);
INSERT INTO division VALUES (96, 'Kowloon City', 'Kowloon City', 187);
INSERT INTO division VALUES (97, 'Kowloon Tong', 'Kowloon Tong', 187);
INSERT INTO division VALUES (98, 'Kwun Tong', 'Kwun Tong', 187);
INSERT INTO division VALUES (99, 'Lai Chi Kok', 'Lai Chi Kok', 187);
INSERT INTO division VALUES (100, 'Lam Tin', 'Lam Tin', 187);
INSERT INTO division VALUES (101, 'Lei Yue Mun', 'Lei Yue Mun', 187);
INSERT INTO division VALUES (102, 'Lok Fu', 'Lok Fu', 187);
INSERT INTO division VALUES (103, 'Mei Foo', 'Mei Foo', 187);
INSERT INTO division VALUES (104, 'Mong Kok', 'Mong Kok', 187);
INSERT INTO division VALUES (105, 'Ngau Tau Kok', 'Ngau Tau Kok', 187);
INSERT INTO division VALUES (106, 'Prince Edward', 'Prince Edward', 187);
INSERT INTO division VALUES (107, 'San Po Kong', 'San Po Kong', 187);
INSERT INTO division VALUES (108, 'Sham Shui Po', 'Sham Shui Po', 187);
INSERT INTO division VALUES (109, 'Shek Kip Mei', 'Shek Kip Mei', 187);
INSERT INTO division VALUES (110, 'Tai Kwok Tsui', 'Tai Kwok Tsui', 187);
INSERT INTO division VALUES (111, 'To Kwa Wan', 'To Kwa Wan', 187);
INSERT INTO division VALUES (112, 'Tsim Sha Tsui', 'Tsim Sha Tsui', 187);
INSERT INTO division VALUES (113, 'Tsz Wan Shan', 'Tsz Wan Shan', 187);
INSERT INTO division VALUES (114, 'Whampoa Garden', 'Whampoa Garden', 187);
INSERT INTO division VALUES (115, 'Wong Tai Sin', 'Wong Tai Sin', 187);
INSERT INTO division VALUES (116, 'Yau Ma Tei', 'Yau Ma Tei', 187);
INSERT INTO division VALUES (117, 'Yau Tong', 'Yau Tong', 187);
INSERT INTO division VALUES (118, 'Fanling', 'Fanling', 187);
INSERT INTO division VALUES (119, 'Fo Tan', 'Fo Tan', 187);
INSERT INTO division VALUES (120, 'Kwai Chung', 'Kwai Chung', 187);
INSERT INTO division VALUES (121, 'Kwai Fong', 'Kwai Fong', 187);
INSERT INTO division VALUES (122, 'Lau Fau Shan', 'Lau Fau Shan', 187);
INSERT INTO division VALUES (123, 'Lo Wu', 'Lo Wu', 187);
INSERT INTO division VALUES (124, 'Lok Ma Chau', 'Lok Ma Chau', 187);
INSERT INTO division VALUES (125, 'Ma On Shan', 'Ma On Shan', 187);
INSERT INTO division VALUES (126, 'Ma Wan', 'Ma Wan', 187);
INSERT INTO division VALUES (127, 'Sai Kung', 'Sai Kung', 187);
INSERT INTO division VALUES (128, 'Sha Tin', 'Sha Tin', 187);
INSERT INTO division VALUES (129, 'Sham Tseng', 'Sham Tseng', 187);
INSERT INTO division VALUES (130, 'Sheung Shui', 'Sheung Shui', 187);
INSERT INTO division VALUES (131, 'Tai Po', 'Tai Po', 187);
INSERT INTO division VALUES (132, 'Tai Wai', 'Tai Wai', 187);
INSERT INTO division VALUES (133, 'Tai Wo', 'Tai Wo', 187);
INSERT INTO division VALUES (134, 'Tin Shui Wai', 'Tin Shui Wai', 187);
INSERT INTO division VALUES (135, 'Tseung Kwan O', 'Tseung Kwan O', 187);
INSERT INTO division VALUES (136, 'Tsing Yi', 'Tsing Yi', 187);
INSERT INTO division VALUES (137, 'Tsuen Wan', 'Tsuen Wan', 187);
INSERT INTO division VALUES (138, 'Tuen Mun', 'Tuen Mun', 187);
INSERT INTO division VALUES (139, 'Yuen Long', 'Yuen Long', 187);
INSERT INTO division VALUES (140, 'Cheung Chau', 'Cheung Chau', 187);
INSERT INTO division VALUES (141, 'Lamma Island', 'Lamma Island', 187);
INSERT INTO division VALUES (142, 'Lantau Island', 'Lantau Island', 187);
INSERT INTO division VALUES (143, 'Ping Chau', 'Ping Chau', 187);
INSERT INTO division VALUES (144, 'Po Toi Island', 'Po Toi Island', 187);
INSERT INTO division VALUES (145, 'Tai O', 'Tai O', 187);


--
-- Name: division_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('division_id_seq', 145, true);


--
-- Data for Name: language; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO language VALUES (1, 'en', 'English');
INSERT INTO language VALUES (2, 'fr', 'French');
INSERT INTO language VALUES (3, 'de', 'German');
INSERT INTO language VALUES (4, 'zh', 'Simplified Chinese');


--
-- Name: language_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('language_id_seq', 4, true);


--
-- Data for Name: locale; Type: TABLE DATA; Schema: public; Owner: sos
--

INSERT INTO locale VALUES (1, 94, 1);
INSERT INTO locale VALUES (2, 1, 1);
INSERT INTO locale VALUES (3, 96, 2);
INSERT INTO locale VALUES (4, 65, 3);
INSERT INTO locale VALUES (5, 150, 4);


--
-- Name: locale_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('locale_id_seq', 5, true);


--
-- Data for Name: post_code; Type: TABLE DATA; Schema: public; Owner: sos
--



--
-- Data for Name: post_code_group; Type: TABLE DATA; Schema: public; Owner: sos
--



--
-- Name: post_code_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('post_code_group_id_seq', 1, true);


--
-- Data for Name: post_code_group_member; Type: TABLE DATA; Schema: public; Owner: sos
--



--
-- Name: post_code_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sos
--

SELECT pg_catalog.setval('post_code_id_seq', 1, false);


SET search_path = shipping, pg_catalog;

--
-- Data for Name: attribute; Type: TABLE DATA; Schema: shipping; Owner: sos
--

INSERT INTO attribute VALUES (1, 'Chinese Origin', 'CH_ORIGIN');
INSERT INTO attribute VALUES (2, 'CITES', 'CITES');
INSERT INTO attribute VALUES (3, 'Fish & Wildlife', 'FISH_WILD');
INSERT INTO attribute VALUES (4, 'Fine Jewelry', 'FINE_JEWEL');
INSERT INTO attribute VALUES (5, 'Figures', 'FIGURES');
INSERT INTO attribute VALUES (6, 'Goose Feathers', 'GOOSE');
INSERT INTO attribute VALUES (7, 'Middle East', 'MIDDLEEAST');
INSERT INTO attribute VALUES (8, 'Non-Hazmat beauty', 'NONHMB');
INSERT INTO attribute VALUES (9, 'Jewellery', 'JEWELLERY');
INSERT INTO attribute VALUES (10, 'Hazmat', 'HAZMAT');
INSERT INTO attribute VALUES (11, 'Headphones & Speakers', 'HPANDSP');
INSERT INTO attribute VALUES (12, 'Hazmat EQ', 'HZMT_EQ');
INSERT INTO attribute VALUES (13, 'Hazmat Aerosol', 'HZMT_AERO');
INSERT INTO attribute VALUES (14, 'SMN beauty products', 'SMN_BEAUTY');
INSERT INTO attribute VALUES (15, 'Do Not Export', 'DO_NOT_EXP');
INSERT INTO attribute VALUES (16, 'Hazmat LQ', 'HZMT_LQ');
INSERT INTO attribute VALUES (17, 'Bike', 'BIKE');


--
-- Name: attribute_id_seq; Type: SEQUENCE SET; Schema: shipping; Owner: sos
--

SELECT pg_catalog.setval('attribute_id_seq', 17, true);


--
-- Data for Name: availability; Type: TABLE DATA; Schema: shipping; Owner: sos
--



--
-- Name: availability_id_seq; Type: SEQUENCE SET; Schema: shipping; Owner: sos
--

SELECT pg_catalog.setval('availability_id_seq', 1, false);


--
-- Data for Name: availability_promotion_group; Type: TABLE DATA; Schema: shipping; Owner: sos
--



--
-- Data for Name: availability_restriction; Type: TABLE DATA; Schema: shipping; Owner: sos
--



--
-- Name: availability_restriction_id_seq; Type: SEQUENCE SET; Schema: shipping; Owner: sos
--

SELECT pg_catalog.setval('availability_restriction_id_seq', 1, false);


--
-- Data for Name: country_restriction; Type: TABLE DATA; Schema: shipping; Owner: sos
--



--
-- Data for Name: description; Type: TABLE DATA; Schema: shipping; Owner: sos
--



--
-- Name: description_id_seq; Type: SEQUENCE SET; Schema: shipping; Owner: sos
--

SELECT pg_catalog.setval('description_id_seq', 1, false);


--
-- Data for Name: division_restriction; Type: TABLE DATA; Schema: shipping; Owner: sos
--



--
-- Data for Name: option; Type: TABLE DATA; Schema: shipping; Owner: sos
--

INSERT INTO option VALUES (1, 'Standard', 'STANDARD', false);
INSERT INTO option VALUES (2, 'Express', 'EXPRESS', false);
INSERT INTO option VALUES (3, 'Next Day', 'NEXTDAY', false);
INSERT INTO option VALUES (4, 'Courier', 'COURIER', false);
INSERT INTO option VALUES (5, 'Staff', 'STAFF', false);
INSERT INTO option VALUES (6, 'Transfer', 'TRANSFER', false);
INSERT INTO option VALUES (8, 'Premier Daytime', 'PREMDAY', true);
INSERT INTO option VALUES (9, 'Premier Evening', 'PREMEVE', true);
INSERT INTO option VALUES (10, 'Nominated Day', 'NOMDAY', true);
INSERT INTO option VALUES (7, 'Premier Anytime', 'PREMANY', false);


--
-- Name: option_id_seq; Type: SEQUENCE SET; Schema: shipping; Owner: sos
--

SELECT pg_catalog.setval('option_id_seq', 10, true);


--
-- Data for Name: packaging_group; Type: TABLE DATA; Schema: shipping; Owner: sos
--

INSERT INTO packaging_group VALUES (1, 'Standard', 'STD');
INSERT INTO packaging_group VALUES (2, 'Premier', 'PRE');


--
-- Name: packaging_group_id_seq; Type: SEQUENCE SET; Schema: shipping; Owner: sos
--

SELECT pg_catalog.setval('packaging_group_id_seq', 2, true);


--
-- Data for Name: post_code_restriction; Type: TABLE DATA; Schema: shipping; Owner: sos
--



--
-- Data for Name: promotion_group; Type: TABLE DATA; Schema: shipping; Owner: sos
--



--
-- Name: promotion_group_id_seq; Type: SEQUENCE SET; Schema: shipping; Owner: sos
--

SELECT pg_catalog.setval('promotion_group_id_seq', 5, true);


--
-- Data for Name: signature_required_status; Type: TABLE DATA; Schema: shipping; Owner: sos
--

INSERT INTO signature_required_status VALUES (1, 'Yes', 'YES');
INSERT INTO signature_required_status VALUES (2, 'No', 'NO');
INSERT INTO signature_required_status VALUES (3, 'Optional', 'OPTIONAL');


--
-- Name: signature_required_status_id_seq; Type: SEQUENCE SET; Schema: shipping; Owner: sos
--

SELECT pg_catalog.setval('signature_required_status_id_seq', 3, true);


SET search_path = delivery, pg_catalog;

--
-- Name: event_pkey; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- Name: event_type_code_key; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY event_type
    ADD CONSTRAINT event_type_code_key UNIQUE (code);


--
-- Name: event_type_name_key; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY event_type
    ADD CONSTRAINT event_type_name_key UNIQUE (name);


--
-- Name: event_type_pkey; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY event_type
    ADD CONSTRAINT event_type_pkey PRIMARY KEY (id);


--
-- Name: file_filename_key; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY file
    ADD CONSTRAINT file_filename_key UNIQUE (filename);


--
-- Name: file_pkey; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY file
    ADD CONSTRAINT file_pkey PRIMARY KEY (id);


--
-- Name: restriction_pkey; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY restriction
    ADD CONSTRAINT restriction_pkey PRIMARY KEY (id);


--
-- Name: restriction_restricted_date_shipping_availability_id_stage__key; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY restriction
    ADD CONSTRAINT restriction_restricted_date_shipping_availability_id_stage__key UNIQUE (restricted_date, shipping_availability_id, stage_id);


--
-- Name: stage_code_key; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY stage
    ADD CONSTRAINT stage_code_key UNIQUE (code);


--
-- Name: stage_days_to_complete_pkey; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY stage_days_to_complete
    ADD CONSTRAINT stage_days_to_complete_pkey PRIMARY KEY (id);


--
-- Name: stage_name_key; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY stage
    ADD CONSTRAINT stage_name_key UNIQUE (name);


--
-- Name: stage_pkey; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY stage
    ADD CONSTRAINT stage_pkey PRIMARY KEY (id);


--
-- Name: stage_ranking_key; Type: CONSTRAINT; Schema: delivery; Owner: sos; Tablespace:
--

ALTER TABLE ONLY stage
    ADD CONSTRAINT stage_ranking_key UNIQUE (ranking);


SET search_path = public, pg_catalog;

--
-- Name: business_code_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY business
    ADD CONSTRAINT business_code_key UNIQUE (code);


--
-- Name: business_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY business
    ADD CONSTRAINT business_pkey PRIMARY KEY (id);


--
-- Name: carrier_code_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY carrier
    ADD CONSTRAINT carrier_code_key UNIQUE (code);


--
-- Name: carrier_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY carrier
    ADD CONSTRAINT carrier_pkey PRIMARY KEY (id);


--
-- Name: country_code_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY country
    ADD CONSTRAINT country_code_key UNIQUE (code);


--
-- Name: country_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY country
    ADD CONSTRAINT country_pkey PRIMARY KEY (id);


--
-- Name: currency_code_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY currency
    ADD CONSTRAINT currency_code_key UNIQUE (code);


--
-- Name: currency_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (id);


--
-- Name: dc_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY dc
    ADD CONSTRAINT dc_pkey PRIMARY KEY (id);


--
-- Name: division_code_country_id_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY division
    ADD CONSTRAINT division_code_country_id_key UNIQUE (code, country_id);


--
-- Name: division_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY division
    ADD CONSTRAINT division_pkey PRIMARY KEY (id);


--
-- Name: language_code_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY language
    ADD CONSTRAINT language_code_key UNIQUE (code);


--
-- Name: language_description_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY language
    ADD CONSTRAINT language_description_key UNIQUE (description);


--
-- Name: language_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY language
    ADD CONSTRAINT language_pkey PRIMARY KEY (id);


--
-- Name: locale_country_id_language_id_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY locale
    ADD CONSTRAINT locale_country_id_language_id_key UNIQUE (country_id, language_id);


--
-- Name: locale_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY locale
    ADD CONSTRAINT locale_pkey PRIMARY KEY (id);


--
-- Name: pk_databasechangeloglock; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY databasechangeloglock
    ADD CONSTRAINT pk_databasechangeloglock PRIMARY KEY (id);


--
-- Name: post_code_code_country_id_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY post_code
    ADD CONSTRAINT post_code_code_country_id_key UNIQUE (code, country_id);


--
-- Name: post_code_group_code_key; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY post_code_group
    ADD CONSTRAINT post_code_group_code_key UNIQUE (code);


--
-- Name: post_code_group_member_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY post_code_group_member
    ADD CONSTRAINT post_code_group_member_pkey PRIMARY KEY (post_code_group_id, post_code_id);


--
-- Name: post_code_group_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY post_code_group
    ADD CONSTRAINT post_code_group_pkey PRIMARY KEY (id);


--
-- Name: post_code_pkey; Type: CONSTRAINT; Schema: public; Owner: sos; Tablespace:
--

ALTER TABLE ONLY post_code
    ADD CONSTRAINT post_code_pkey PRIMARY KEY (id);


SET search_path = shipping, pg_catalog;

--
-- Name: attribute_code_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY attribute
    ADD CONSTRAINT attribute_code_key UNIQUE (code);


--
-- Name: attribute_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY attribute
    ADD CONSTRAINT attribute_pkey PRIMARY KEY (id);


--
-- Name: availability_option_id_business_id_country_id_dc_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_option_id_business_id_country_id_dc_key UNIQUE (option_id, business_id, country_id, "DC");


--
-- Name: availability_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_pkey PRIMARY KEY (id);


--
-- Name: availability_promotion_group_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY availability_promotion_group
    ADD CONSTRAINT availability_promotion_group_pkey PRIMARY KEY (availability_id, promotion_group_id);


--
-- Name: availability_restriction_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY availability_restriction
    ADD CONSTRAINT availability_restriction_pkey PRIMARY KEY (id);


--
-- Name: country_restriction_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY country_restriction
    ADD CONSTRAINT country_restriction_pkey PRIMARY KEY (attribute_id, country_id, "DC");


--
-- Name: description_locale_id_shipping_availability_id_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY description
    ADD CONSTRAINT description_locale_id_shipping_availability_id_key UNIQUE (locale_id, shipping_availability_id);


--
-- Name: description_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY description
    ADD CONSTRAINT description_pkey PRIMARY KEY (id);


--
-- Name: division_restriction_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY division_restriction
    ADD CONSTRAINT division_restriction_pkey PRIMARY KEY (attribute_id, division_id);


--
-- Name: option_code_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY option
    ADD CONSTRAINT option_code_key UNIQUE (code);


--
-- Name: option_id_business_id_division_id_dc_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT option_id_business_id_division_id_dc_key UNIQUE (option_id, business_id, division_id, "DC");


--
-- Name: option_id_business_id_post_code_group_id_dc_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT option_id_business_id_post_code_group_id_dc_key UNIQUE (option_id, business_id, post_code_group_id, "DC");


--
-- Name: option_name_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY option
    ADD CONSTRAINT option_name_key UNIQUE (name);


--
-- Name: option_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY option
    ADD CONSTRAINT option_pkey PRIMARY KEY (id);


--
-- Name: packaging_group_code_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY packaging_group
    ADD CONSTRAINT packaging_group_code_key UNIQUE (code);


--
-- Name: packaging_group_name_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY packaging_group
    ADD CONSTRAINT packaging_group_name_key UNIQUE (name);


--
-- Name: packaging_group_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY packaging_group
    ADD CONSTRAINT packaging_group_pkey PRIMARY KEY (id);


--
-- Name: post_code_restriction_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY post_code_restriction
    ADD CONSTRAINT post_code_restriction_pkey PRIMARY KEY (attribute_id, post_code_group_id);


--
-- Name: promotion_group_code_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY promotion_group
    ADD CONSTRAINT promotion_group_code_key UNIQUE (code);


--
-- Name: promotion_group_name_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY promotion_group
    ADD CONSTRAINT promotion_group_name_key UNIQUE (name);


--
-- Name: promotion_group_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY promotion_group
    ADD CONSTRAINT promotion_group_pkey PRIMARY KEY (id);


--
-- Name: signature_required_status_code_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY signature_required_status
    ADD CONSTRAINT signature_required_status_code_key UNIQUE (code);


--
-- Name: signature_required_status_name_key; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY signature_required_status
    ADD CONSTRAINT signature_required_status_name_key UNIQUE (name);


--
-- Name: signature_required_status_pkey; Type: CONSTRAINT; Schema: shipping; Owner: sos; Tablespace:
--

ALTER TABLE ONLY signature_required_status
    ADD CONSTRAINT signature_required_status_pkey PRIMARY KEY (id);


SET search_path = public, pg_catalog;

--
-- Name: dc_code_uindex; Type: INDEX; Schema: public; Owner: sos; Tablespace:
--

CREATE UNIQUE INDEX dc_code_uindex ON dc USING btree (code);


--
-- Name: dc_id_uindex; Type: INDEX; Schema: public; Owner: sos; Tablespace:
--

CREATE UNIQUE INDEX dc_id_uindex ON dc USING btree (id);


SET search_path = shipping, pg_catalog;

--
-- Name: idx_attribute_availability; Type: INDEX; Schema: shipping; Owner: sos; Tablespace:
--

CREATE UNIQUE INDEX idx_attribute_availability ON availability_restriction USING btree (attribute_id, availability_id);


SET search_path = delivery, pg_catalog;

--
-- Name: event_carrier_id_fkey; Type: FK CONSTRAINT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_carrier_id_fkey FOREIGN KEY (carrier_id) REFERENCES public.carrier(id);


--
-- Name: event_delivery_event_type_id_fkey; Type: FK CONSTRAINT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_delivery_event_type_id_fkey FOREIGN KEY (delivery_event_type_id) REFERENCES event_type(id);


--
-- Name: file_carrier_id_fkey; Type: FK CONSTRAINT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY file
    ADD CONSTRAINT file_carrier_id_fkey FOREIGN KEY (carrier_id) REFERENCES public.carrier(id);


--
-- Name: restriction_shipping_availability_id_fkey; Type: FK CONSTRAINT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY restriction
    ADD CONSTRAINT restriction_shipping_availability_id_fkey FOREIGN KEY (shipping_availability_id) REFERENCES shipping.availability(id);


--
-- Name: restriction_stage_id_fkey; Type: FK CONSTRAINT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY restriction
    ADD CONSTRAINT restriction_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES stage(id);


--
-- Name: stage_days_to_complete_shipping_availability_id_fkey; Type: FK CONSTRAINT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY stage_days_to_complete
    ADD CONSTRAINT stage_days_to_complete_shipping_availability_id_fkey FOREIGN KEY (shipping_availability_id) REFERENCES shipping.availability(id);


--
-- Name: stage_days_to_complete_stage_id_fkey; Type: FK CONSTRAINT; Schema: delivery; Owner: sos
--

ALTER TABLE ONLY stage_days_to_complete
    ADD CONSTRAINT stage_days_to_complete_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES stage(id);


SET search_path = public, pg_catalog;

--
-- Name: division_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sos
--

ALTER TABLE ONLY division
    ADD CONSTRAINT division_country_id_fkey FOREIGN KEY (country_id) REFERENCES country(id);


--
-- Name: locale_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sos
--

ALTER TABLE ONLY locale
    ADD CONSTRAINT locale_country_id_fkey FOREIGN KEY (country_id) REFERENCES country(id);


--
-- Name: locale_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sos
--

ALTER TABLE ONLY locale
    ADD CONSTRAINT locale_language_id_fkey FOREIGN KEY (language_id) REFERENCES language(id);


--
-- Name: post_code_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sos
--

ALTER TABLE ONLY post_code
    ADD CONSTRAINT post_code_country_id_fkey FOREIGN KEY (country_id) REFERENCES country(id);


--
-- Name: post_code_group_member_post_code_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sos
--

ALTER TABLE ONLY post_code_group_member
    ADD CONSTRAINT post_code_group_member_post_code_group_id_fkey FOREIGN KEY (post_code_group_id) REFERENCES post_code_group(id);


--
-- Name: post_code_group_member_post_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sos
--

ALTER TABLE ONLY post_code_group_member
    ADD CONSTRAINT post_code_group_member_post_code_id_fkey FOREIGN KEY (post_code_id) REFERENCES post_code(id);


SET search_path = shipping, pg_catalog;

--
-- Name: availability_DC_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT "availability_DC_fkey" FOREIGN KEY ("DC") REFERENCES public.dc(code);


--
-- Name: availability_business_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_business_id_fkey FOREIGN KEY (business_id) REFERENCES public.business(id);


--
-- Name: availability_country_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.country(id);


--
-- Name: availability_currency_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.currency(id);


--
-- Name: availability_division_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.division(id);


--
-- Name: availability_option_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_option_id_fkey FOREIGN KEY (option_id) REFERENCES option(id);


--
-- Name: availability_packaging_group_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_packaging_group_id_fkey FOREIGN KEY (packaging_group_id) REFERENCES packaging_group(id);


--
-- Name: availability_post_code_group_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_post_code_group_id_fkey FOREIGN KEY (post_code_group_id) REFERENCES public.post_code_group(id);


--
-- Name: availability_promotion_group_availability_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability_promotion_group
    ADD CONSTRAINT availability_promotion_group_availability_id_fkey FOREIGN KEY (availability_id) REFERENCES availability(id);


--
-- Name: availability_promotion_group_promotion_group_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability_promotion_group
    ADD CONSTRAINT availability_promotion_group_promotion_group_id_fkey FOREIGN KEY (promotion_group_id) REFERENCES promotion_group(id);


--
-- Name: availability_restriction_attribute_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability_restriction
    ADD CONSTRAINT availability_restriction_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES attribute(id);


--
-- Name: availability_restriction_availability_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability_restriction
    ADD CONSTRAINT availability_restriction_availability_id_fkey FOREIGN KEY (availability_id) REFERENCES availability(id);


--
-- Name: availability_signature_required_status_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY availability
    ADD CONSTRAINT availability_signature_required_status_id_fkey FOREIGN KEY (signature_required_status_id) REFERENCES signature_required_status(id);


--
-- Name: country_restriction_DC_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY country_restriction
    ADD CONSTRAINT "country_restriction_DC_fkey" FOREIGN KEY ("DC") REFERENCES public.dc(code);


--
-- Name: country_restriction_attribute_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY country_restriction
    ADD CONSTRAINT country_restriction_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES attribute(id);


--
-- Name: country_restriction_country_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY country_restriction
    ADD CONSTRAINT country_restriction_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.country(id);


--
-- Name: description_locale_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY description
    ADD CONSTRAINT description_locale_id_fkey FOREIGN KEY (locale_id) REFERENCES public.locale(id);


--
-- Name: description_shipping_availability_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY description
    ADD CONSTRAINT description_shipping_availability_id_fkey FOREIGN KEY (shipping_availability_id) REFERENCES availability(id);


--
-- Name: division_restriction_DC_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY division_restriction
    ADD CONSTRAINT "division_restriction_DC_fkey" FOREIGN KEY ("DC") REFERENCES public.dc(code);


--
-- Name: division_restriction_attribute_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY division_restriction
    ADD CONSTRAINT division_restriction_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES attribute(id);


--
-- Name: division_restriction_division_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY division_restriction
    ADD CONSTRAINT division_restriction_division_id_fkey FOREIGN KEY (division_id) REFERENCES public.division(id);


--
-- Name: post_code_restriction_DC_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY post_code_restriction
    ADD CONSTRAINT "post_code_restriction_DC_fkey" FOREIGN KEY ("DC") REFERENCES public.dc(code);


--
-- Name: post_code_restriction_attribute_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY post_code_restriction
    ADD CONSTRAINT post_code_restriction_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES attribute(id);


--
-- Name: post_code_restriction_post_code_group_id_fkey; Type: FK CONSTRAINT; Schema: shipping; Owner: sos
--

ALTER TABLE ONLY post_code_restriction
    ADD CONSTRAINT post_code_restriction_post_code_group_id_fkey FOREIGN KEY (post_code_group_id) REFERENCES public.post_code_group(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

