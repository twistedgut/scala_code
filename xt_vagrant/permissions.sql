BEGIN;

create or replace function superpowers(uname varchar,email varchar,autologin integer) returns void as $$
    BEGIN
       update operator set auto_login=autologin where username=uname;
       update operator set disabled=0 where username=uname;
       update operator set email_address=email where username=uname;

       delete from operator_authorisation where operator_id=(select id from operator where username=uname);

       insert into operator_authorisation (operator_id,authorisation_sub_section_id,authorisation_level_id)
           select (select id from operator where username=uname), id,
           (select id from authorisation_level where description='Manager') from authorisation_sub_section;
   END;
$$ language plpgsql;

COMMIT;

select superpowers('j.maslen', 'john.maslen@net-a-porter.com', 0);
