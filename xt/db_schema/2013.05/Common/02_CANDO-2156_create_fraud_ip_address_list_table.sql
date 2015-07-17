-- CANDO-2156: Adds ip_address_whitelist table to
--             'fraud' Schema

BEGIN WORK;

--
-- IP Address Status
--

CREATE TABLE public.security_list_status (
    id          SERIAL NOT NULL PRIMARY KEY,
    status      CHARACTER VARYING(255) NOT NULL,
    UNIQUE (status)
);
ALTER TABLE public.security_list_status OWNER TO postgres;
GRANT ALL ON TABLE  public.security_list_status TO www;
GRANT ALL ON SEQUENCE public.security_list_status_id_seq TO www;

--
-- IP Address Whitelist
--
CREATE TABLE fraud.ip_address_list (
    id          SERIAL NOT NULL PRIMARY KEY,
    ip_address      CHARACTER VARYING(45) NOT NULL,
    status_id   INTEGER NOT NULL REFERENCES public.security_list_status(id),
    created  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    operator_id INTEGER NOT NULL REFERENCES public.operator(id),
    UNIQUE (ip_address)
);
ALTER TABLE fraud.ip_address_list OWNER TO postgres;
GRANT ALL ON TABLE fraud.ip_address_list TO www;
GRANT ALL ON SEQUENCE fraud.ip_address_list_id_seq TO www;

--
-- Populate Tables
--

INSERT INTO public.security_list_status (status) VALUES
    ('Whitelist'),
    ('Blacklist'),
    ('Internal')
;

INSERT INTO fraud.ip_address_list (ip_address, status_id, operator_id) VALUES
    ('127.0.0.1',
    (SELECT id FROM public.security_list_status WHERE status = 'Internal'),
    1)
;

COMMIT WORK;
