BEGIN WORK;

INSERT INTO authorisation_sub_section(authorisation_section_id, sub_section, ord)
       VALUES(1, 'Fraud Rules', 99);

COMMIT WORK;
