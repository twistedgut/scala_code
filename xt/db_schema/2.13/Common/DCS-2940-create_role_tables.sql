-- Create user2role_id and role_id2name tables for basic roles based authorisation
-- Also adds first 2 users with roles

BEGIN;

    CREATE TABLE public.role
        (
            id INT UNIQUE NOT NULL,
            role_name VARCHAR(255) UNIQUE NOT NULL,
            PRIMARY KEY (id)
        );
        
    grant all on public.role TO postgres;
    grant all on public.role TO www;
    
    CREATE SEQUENCE role_sequence;

    grant all on public.role_sequence TO postgres;
    grant all on public.role_sequence TO www;
    
    ALTER TABLE role ALTER COLUMN id SET DEFAULT NEXTVAL('role_sequence');

    INSERT INTO public.role (role_name) VALUES ('Web content administrator');
    
    ---------------------------------------------------------------------------

    CREATE TABLE public.operator_role
        (   
            id INT UNIQUE NOT NULL,
            operator_id INT NOT NULL,
            role_id INT REFERENCES public.role (id) NOT NULL,
            PRIMARY KEY (id)
        );
        
    grant all on public.operator_role TO postgres;
    grant all on public.operator_role TO www;

    CREATE SEQUENCE operator_role_sequence;

    grant all on public.operator_role_sequence TO postgres;
    grant all on public.operator_role_sequence TO www;
    
    ALTER TABLE operator_role ALTER COLUMN id SET DEFAULT NEXTVAL('operator_role_sequence');

    INSERT INTO public.operator_role (operator_id,role_id) VALUES (5382,1);
    INSERT INTO public.operator_role (operator_id,role_id) VALUES (188,1);
    INSERT INTO public.operator_role (operator_id,role_id) VALUES (5009,1);
    
COMMIT;


