-- DCA-591: Create putaway_prep_group table to store PGID details
--          for Putaway Prep Overview page

BEGIN;

-- status table
CREATE SEQUENCE putaway_prep_group_status_id_seq
    INCREMENT BY 1 NO MAXVALUE NO MINVALUE START WITH 1 CACHE 1;

create table putaway_prep_group_status (
    id INTEGER PRIMARY KEY DEFAULT NEXTVAL('putaway_prep_group_status_id_seq'),
    status VARCHAR(255) NOT NULL,
    description VARCHAR(255) NOT NULL
);

ALTER SEQUENCE putaway_prep_group_status_id_seq OWNER TO postgres;
GRANT ALL ON SEQUENCE putaway_prep_group_status_id_seq TO postgres;
GRANT ALL ON SEQUENCE putaway_prep_group_status_id_seq TO www;

ALTER TABLE putaway_prep_group_status OWNER TO postgres;
GRANT ALL ON TABLE putaway_prep_group_status TO postgres;
GRANT ALL ON TABLE putaway_prep_group_status TO www;

INSERT INTO putaway_prep_group_status (status, description) VALUES
    ('In Progress', 'At least one item has been scanned in putaway prep'),
    ('Completed', 'All items have been scanned, and group completed correctly'),
    ('Problem', 'Quantity completed is more than expected'),
    ('Resolved', 'An operator has manually marked a group as okay');

-- group table
CREATE SEQUENCE putaway_prep_group_id_seq
    INCREMENT BY 1 NO MAXVALUE NO MINVALUE START WITH 1 CACHE 1;

CREATE TABLE putaway_prep_group (
    id INTEGER PRIMARY KEY DEFAULT NEXTVAL('putaway_prep_group_id_seq'),
    status_id INTEGER NOT NULL REFERENCES putaway_prep_group_status(id) DEFERRABLE
);

ALTER SEQUENCE putaway_prep_group_id_seq OWNER TO postgres;
GRANT ALL ON SEQUENCE putaway_prep_group_id_seq TO postgres;
GRANT ALL ON SEQUENCE putaway_prep_group_id_seq TO www;

ALTER TABLE putaway_prep_group OWNER TO postgres;
GRANT ALL ON TABLE putaway_prep_group TO postgres;
GRANT ALL ON TABLE putaway_prep_group TO www;

COMMIT;
