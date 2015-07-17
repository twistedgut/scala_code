BEGIN;

-- for a start, remove all operator preferences - they may not make sense in DC3 if they were copied from DC2
delete from operator_preferences;

-- remove permissions of anybody who's account is not yet enbabled.
delete from operator_authorisation where operator_id in (select id from operator where disabled = 1);

COMMIT;
