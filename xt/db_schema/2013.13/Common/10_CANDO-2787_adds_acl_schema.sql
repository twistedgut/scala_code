-- CANDO-2787: Adds new 'acl' Schema

BEGIN WORK;

-- acl schema

CREATE SCHEMA acl;
GRANT ALL ON SCHEMA acl TO postgres;
GRANT ALL ON SCHEMA acl TO www;

-- Role

CREATE TABLE acl.authorisation_role (
    id                 SERIAL NOT NULL PRIMARY KEY,
    authorisation_role CHARACTER VARYING (255) NOT NULL UNIQUE
);
CREATE UNIQUE INDEX authorisation_role_authorisation_role_lcase_idx ON acl.authorisation_role( LOWER(authorisation_role::text) );
ALTER TABLE acl.authorisation_role OWNER TO postgres;
GRANT ALL ON TABLE acl.authorisation_role TO www;
GRANT ALL ON SEQUENCE acl.authorisation_role_id_seq TO www;

-- URL Path

CREATE TABLE acl.url_path (
    id          SERIAL NOT NULL PRIMARY KEY,
    url_path    CHARACTER VARYING (255) NOT NULL UNIQUE
);

ALTER TABLE acl.url_path OWNER TO postgres;
GRANT ALL ON TABLE acl.url_path TO www;
GRANT ALL ON SEQUENCE acl.url_path_id_seq TO www;

-- Link Role to URL Path

CREATE TABLE acl.link_authorisation_role__url_path (
    authorisation_role_id INTEGER NOT NULL REFERENCES acl.authorisation_role(id),
    url_path_id           INTEGER NOT NULL REFERENCES acl.url_path(id),
    PRIMARY KEY( authorisation_role_id, url_path_id )
);

ALTER TABLE acl.link_authorisation_role__url_path OWNER TO postgres;
GRANT ALL ON TABLE acl.link_authorisation_role__url_path TO www;

-- Link Role to Authorisation Sub Section

CREATE TABLE acl.link_authorisation_role__authorisation_sub_section (
    authorisation_role_id           INTEGER NOT NULL REFERENCES acl.authorisation_role(id),
    authorisation_sub_section_id    INTEGER NOT NULL REFERENCES public.authorisation_sub_section(id),
    PRIMARY KEY( authorisation_role_id, authorisation_sub_section_id )
);

ALTER TABLE acl.link_authorisation_role__authorisation_sub_section OWNER TO postgres;
GRANT ALL ON TABLE acl.link_authorisation_role__authorisation_sub_section TO www;

COMMIT WORK;
