-- renaming Fulfilment departments to Distribution

BEGIN;

update department set department = 'Distribution' where department = 'Fulfilment';
update department set department = 'Distribution Management' where department = 'Fulfilment Manager';

COMMIT;
