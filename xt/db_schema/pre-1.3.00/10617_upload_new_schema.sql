-- Upload schame
--   Jason Tang ( August 2007 )


BEGIN;

CREATE SCHEMA upload;
GRANT ALL ON SCHEMA upload TO www;

CREATE TABLE upload.list_info (
    id              SERIAL PRIMARY KEY,
--    order_value INTEGER DEFAULT 0,
    target_value    NUMERIC NOT NULL DEFAULT 0
);

CREATE TABLE upload.list_listinfo (
    id              SERIAL PRIMARY KEY,
    list_id         INTEGER REFERENCES list.list(id),
    listinfo_id     INTEGER REFERENCES upload.list_info(id),
    UNIQUE (list_id, listinfo_id)
);

-- make sure www can use the table
GRANT ALL ON upload.list_info TO www;
GRANT ALL ON upload.list_info_id_seq TO www;
GRANT ALL ON upload.list_listinfo TO www;
GRANT ALL ON upload.list_listinfo_id_seq TO www;


COMMIT;
