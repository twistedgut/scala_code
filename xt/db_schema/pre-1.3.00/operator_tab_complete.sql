-- Description: !OPTIONAL!
-- psql's tab completion script doesn't like 'operator' being used as a 
-- table name.  This table is a hack to make the engine stop at 'operator'
-- instead of completing all the way to 'operator_authorisation'.

BEGIN;

create table operatorhack ( readme text );

insert into operatorhack ( readme ) 
values ( 'psql\'s tab completion script doesn\'t like \'operator\' being used as a table name.  This table is a hack to make the engine stop at \'operator\' instead of completing all the way to \'operator_authorisation\'.' );

COMMIT;

