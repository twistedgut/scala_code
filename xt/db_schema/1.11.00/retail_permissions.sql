-- new schema for website designer navigation management

BEGIN;
INSERT INTO authorisation_section VALUES (default, 'Retail');

-- create new navigation sections
insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Retail'), 'Category Management', 1);
insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Retail'), 'Attribute Management', 2);
insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Retail'), 'Designer Management', 3);

COMMIT;

