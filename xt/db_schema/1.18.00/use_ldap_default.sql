-- We now make people use LDAP authentication
-- so we should default this column to "true" in the operator table
BEGIN;
     ALTER TABLE operator ALTER COLUMN use_ldap SET DEFAULT true;
COMMIT;
