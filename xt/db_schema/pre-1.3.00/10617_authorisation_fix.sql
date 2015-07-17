-- fix up a few problems with public.authorisation_section

BEGIN;

    -- there's aproblem with the sequence value for authorisation_section
    SELECT setval('authorisation_section_id_seq', (select max(id) from authorisation_section), true);

    -- section names should be unique!
    ALTER TABLE authorisation_section ADD CONSTRAINT unique_section_name UNIQUE(section);

COMMIT;
