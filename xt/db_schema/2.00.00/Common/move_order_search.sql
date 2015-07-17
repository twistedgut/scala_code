BEGIN;

update authorisation_sub_section set authorisation_section_id = (select id from authorisation_section where section = 'Customer Care') where sub_section = 'Order Search';

COMMIT;