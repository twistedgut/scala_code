BEGIN;

-- Stock Control > Upload
delete from operator_authorisation where authorisation_sub_section_id = (select id from authorisation_sub_section where sub_section = 'Upload');
delete from authorisation_sub_section where sub_section = 'Upload';

-- Worklists
delete from operator_authorisation where authorisation_sub_section_id in (select id from authorisation_sub_section where sub_section = 'Worklist');
delete from authorisation_sub_section where sub_section = 'Worklist';
delete from operator_authorisation where authorisation_sub_section_id in (select id from authorisation_sub_section where sub_section = 'Outfit');
delete from authorisation_sub_section where sub_section = 'Outfit';
delete from authorisation_section where section = 'Editorial';
delete from authorisation_section where section = 'Photography';
delete from authorisation_section where section = 'Upload';

-- Promotions
delete from operator_authorisation where authorisation_sub_section_id = (select id from authorisation_sub_section where sub_section = 'Manage');
delete from authorisation_sub_section where sub_section = 'Manage';
delete from authorisation_section where section = 'Promotion';

-- Gift Credits
delete from operator_authorisation where authorisation_sub_section_id = (select id from authorisation_sub_section where sub_section = 'Gift Credits');
delete from authorisation_sub_section where sub_section = 'Gift Credits';

-- Live Pricing
delete from operator_authorisation where authorisation_sub_section_id = (select id from authorisation_sub_section where sub_section = 'Live Pricing');
delete from authorisation_sub_section where sub_section = 'Live Pricing';

-- Misc
delete from operator_authorisation where authorisation_sub_section_id = (select id from authorisation_sub_section where sub_section = 'Customer Class Management');
delete from authorisation_sub_section where sub_section = 'Customer Class Management';
delete from operator_authorisation where authorisation_sub_section_id = (select id from authorisation_sub_section where sub_section = 'Category Landing');
delete from authorisation_sub_section where sub_section = 'Category Landing';
delete from operator_authorisation where authorisation_sub_section_id = (select id from authorisation_sub_section where sub_section = 'Search Results');
delete from authorisation_sub_section where sub_section = 'Search Results';

COMMIT;
