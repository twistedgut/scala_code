-- make sure people who need to see tabs are set as 'manager' on relevant sections
-- YUI tabs crash the thin clients so exclude all staff in the "Distribution" dept.
-- they will only see the form entry at top of the page

BEGIN;

update operator_authorisation set authorisation_level_id = 3 
where authorisation_sub_section_id in (select id from authorisation_sub_section where sub_section in ('Picking', 'Packing', 'Airwaybill', 'DDU', 'Dispatch')) 
and operator_id not in (select id from operator where department_id = (select id from department where department = 'Distribution'));

COMMIT;