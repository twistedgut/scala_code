--
-- CANDO-2472: Add shipment_internal_email_log table
--

BEGIN WORK;

CREATE TABLE shipment_internal_email_log (
    id              SERIAL NOT NULL PRIMARY KEY,
    shipment_id     INTEGER NOT NULL REFERENCES public.shipment(id),
    recipient       CHARACTER VARYING (255) NOT NULL,
    template        CHARACTER VARYING (255) NOT NULL,
    subject         CHARACTER VARYING (255) NOT NULL,
    date_sent       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.shipment_internal_email_log OWNER TO postgres;
GRANT ALL ON TABLE public.shipment_internal_email_log TO www;
GRANT ALL ON SEQUENCE public.shipment_internal_email_log_id_seq TO www;

COMMIT WORK;
