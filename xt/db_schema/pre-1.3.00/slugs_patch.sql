-- Purpose:
--  Add new authorisations for the slugs functions

BEGIN;

-- Create a subsection 'Slugs' of section 'Stock Control'
INSERT INTO "authorisation_sub_section" (authorisation_section_id, sub_section) VALUES ((SELECT id FROM authorisation_section WHERE section='Stock Control'), 'Slugs');

-- Check that it worked
SELECT * FROM authorisation_sub_section ass, authorisation_section a_s WHERE ass.sub_section='Slugs' AND ass.authorisation_section_id=a_s.id;

-- Do it!
COMMIT;
