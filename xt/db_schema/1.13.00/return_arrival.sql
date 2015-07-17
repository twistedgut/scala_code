-- table to record the arrival of customer returns by scanning AWB

BEGIN;

insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Goods In'), 'Returns Arrival', (select max(ord) + 1 from authorisation_sub_section where authorisation_section_id = (select id from authorisation_section where section = 'Goods In')));

CREATE TABLE return_arrival (
    id          serial primary key,
    return_airway_bill varchar(30) NOT NULL,
    date     timestamptz NOT NULL default current_timestamp,
    operator_id integer REFERENCES operator(id)
);

GRANT ALL ON public.return_arrival TO www;
GRANT ALL ON public.return_arrival_id_seq TO www;

CREATE INDEX return_arrival_awb ON return_arrival(return_airway_bill);

COMMIT;
