-- Rename table but also a good time to drop out the old one
-- just to clean out all the data that has accumulated.

BEGIN WORK;

drop table public.transaction_code;
drop sequence transaction_code_seq;

-- create the new transaction_code code table, called 'dbl_submit_token'

create table dbl_submit_token (
    id integer not null,
    session_id TEXT
);

ALTER TABLE dbl_submit_token ADD CONSTRAINT dbl_submit_token_pk
    PRIMARY KEY (id);

ALTER TABLE dbl_submit_token ADD CONSTRAINT dbl_submit_token_fk
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE;


ALTER TABLE public.dbl_submit_token OWNER TO www;
GRANT ALL ON TABLE dbl_submit_token TO www;
GRANT SELECT ON TABLE dbl_submit_token TO perlydev;
GRANT ALL ON TABLE dbl_submit_token TO postgres;

-- create the new sequence controlling the tokens

CREATE SEQUENCE dbl_submit_token_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

ALTER TABLE public.dbl_submit_token_seq OWNER TO www;

GRANT ALL ON SEQUENCE dbl_submit_token_seq TO www;
GRANT SELECT ON SEQUENCE dbl_submit_token_seq TO perlydev;
GRANT ALL ON SEQUENCE dbl_submit_token_seq TO postgres;

COMMIT WORK;
