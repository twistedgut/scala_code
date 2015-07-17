-- Picking Overview Page

BEGIN WORK;

ALTER TABLE allocation ADD COLUMN pick_sent timestamp with time zone;

INSERT INTO authorisation_sub_section (authorisation_section_id,sub_section,ord)
    VALUES (2,'Picking Overview',105);

COMMIT WORK;
