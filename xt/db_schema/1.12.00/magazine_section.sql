BEGIN;

insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Web Content'), 'Magazine', 4);

COMMIT;

