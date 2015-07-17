BEGIN;

UPDATE flow.status 
   SET name = 'Dead Stock' 
 WHERE name = 'Dead stock';

COMMIT;
