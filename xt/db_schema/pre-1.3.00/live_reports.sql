-- Purpose:
--  Add new authorisations for the live reports 

BEGIN;

-- Create a subsection 'Live Reports' of section 'Reporting'
INSERT INTO "authorisation_sub_section" (authorisation_section_id, sub_section) VALUES ((SELECT id FROM authorisation_section WHERE section='Reporting'), 'Live Reports');

-- Check that it worked
SELECT * FROM authorisation_sub_section ass, authorisation_section a_s WHERE ass.sub_section='Live Reports' AND ass.authorisation_section_id=a_s.id;

-- Do it!
COMMIT;
