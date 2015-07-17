-- Purpose:
--  Delete The Customer Care/Correspondence menu as it is not used.

BEGIN;

delete from authorisation_sub_section 
where authorisation_section_id in ( 
    select id 
    from authorisation_section 
    where section = 'Customer Care' 
) 
and sub_section = 'Correspondence';

-- Do it!
COMMIT;

