-- CANDO-85: Add 'Reimbursements' to the 'authorisation_sub_section' table

BEGIN WORK;

insert into authorisation_sub_section (authorisation_section_id, sub_section, ord) values (
( select id from authorisation_section where section = 'Finance' ),
'Reimbursements',
( select max(ord)+ 1 from authorisation_sub_section where authorisation_section_id = ( select id from authorisation_section where section = 'Finance' ))
);

COMMIT;
