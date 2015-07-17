BEGIN;

update country set code = 'BL' where code = 'XY';

COMMIT;
