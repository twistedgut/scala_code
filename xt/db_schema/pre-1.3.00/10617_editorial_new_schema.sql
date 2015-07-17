-- Editorial schema
--  Jason Tang ( August 2007 )

BEGIN;

-- new namespace/schema
CREATE SCHEMA editorial;
GRANT ALL ON SCHEMA editorial TO www;

CREATE TABLE editorial.list_info (
    id              SERIAL PRIMARY KEY
);

CREATE TABLE editorial.list_listinfo (
    id              SERIAL PRIMARY KEY,
    list_id         INTEGER REFERENCES list.list(id),
    listinfo_id     INTEGER REFERENCES editorial.list_info(id),
    UNIQUE (list_id, listinfo_id)
);

-- make sure www can use the table
GRANT ALL ON editorial.list_info TO www;
GRANT ALL ON editorial.list_info_id_seq TO www;
GRANT ALL ON editorial.list_listinfo TO www;
GRANT ALL ON editorial.list_listinfo_id_seq TO www;

COMMIT;
