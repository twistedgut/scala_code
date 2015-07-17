-- Rename "Putaway Admin" subsection to be "Putaway Prep Admin"

begin;

update authorisation_sub_section set sub_section = 'Putaway Prep Admin' where sub_section = 'Putaway Admin';

commit;
