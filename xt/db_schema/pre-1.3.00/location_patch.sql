-- Purpose:
--  Add new authorisations for the location create/search/delete/print functions

BEGIN;

-- Create a subsection 'Location' of section 'Stock Control'
INSERT INTO "authorisation_sub_section" (authorisation_section_id, sub_section) VALUES ((SELECT id FROM authorisation_section WHERE section='Stock Control'), 'Location');

-- Check that it worked
SELECT * FROM authorisation_sub_section ass, authorisation_section a_s WHERE ass.sub_section='Location' AND ass.authorisation_section_id=a_s.id;

-- Do it!
COMMIT;
