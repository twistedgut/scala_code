BEGIN;

-- Delete authorisation for page "Admin/Printers"
DELETE FROM operator_authorisation WHERE authorisation_sub_section_id = (SELECT id FROM authorisation_sub_section WHERE sub_section = 'Printers');

-- Clean up remaining orphaned operator_authorisation rows
-- They exist because there's no foreign key linking operator_authorisation to authorisation_sub_section
DELETE FROM operator_authorisation WHERE authorisation_sub_section_id NOT IN (SELECT id FROM authorisation_sub_section);

-- Add the required foreign key constraint
ALTER TABLE operator_authorisation
    ADD CONSTRAINT operator_authorisation_authorisation_sub_section_id_fkey
    FOREIGN KEY (authorisation_sub_section_id) REFERENCES authorisation_sub_section(id);

COMMIT;
