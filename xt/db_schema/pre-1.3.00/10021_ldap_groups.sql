-- LDAP groups within XT
--  This file contains sql updates to allow the turning on of group checking
--  on a user basis to aid migration.
BEGIN;

SELECT 'Dropping department_dir table as it is not used';

DROP TABLE department_dir CASCADE;

SELECT 'Adding use_ldap boolean field to operator';
ALTER TABLE operator ADD use_ldap BOOLEAN DEFAULT FALSE;
ALTER TABLE operator ADD last_login TIMESTAMP WITH TIME ZONE 
    NULL DEFAULT CURRENT_TIMESTAMP;


COMMIT;
