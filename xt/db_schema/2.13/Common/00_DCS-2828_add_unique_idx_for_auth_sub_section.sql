-- DCS-2828: Add a Unique Index on the 'authorisation_sub_section' table for fields 'authorisation_section_id' & 'sub_section'.

BEGIN WORK;

CREATE UNIQUE INDEX authorisation_sub_section_auth_section_id_sub_section_key ON authorisation_sub_section (authorisation_section_id,sub_section);

COMMIT WORK;
