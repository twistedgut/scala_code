-- Purpose: New section under Stock Control
--  

BEGIN;

insert into authorisation_sub_section values (default, (select id from authorisation_section where section = 'Stock Control'), 'Stock Relocation', (select max(ord) + 1 from authorisation_sub_section where authorisation_section_id = (select id from authorisation_section where section = 'Stock Control')));


COMMIT;