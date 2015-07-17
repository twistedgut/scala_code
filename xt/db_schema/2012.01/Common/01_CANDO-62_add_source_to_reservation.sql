-- CANDO-62: Add 'reservation_source' table and populate, Add 'reservation_source_id' column to 'reservation' table

BEGIN WORK;

--
-- Create a Reservation Source table
--
CREATE TABLE reservation_source (
    id          SERIAL NOT NULL PRIMARY KEY,
    source      CHARACTER VARYING(255) NOT NULL UNIQUE,
    sort_order  INTEGER NOT NULL UNIQUE
);

ALTER TABLE reservation_source OWNER TO postgres;
GRANT ALL ON TABLE reservation_source TO postgres;
GRANT ALL ON TABLE reservation_source TO www;

GRANT ALL ON SEQUENCE reservation_source_id_seq TO postgres;
GRANT ALL ON SEQUENCE reservation_source_id_seq TO www;

-- Populate the 'reservation_source' table
INSERT INTO reservation_source (source,sort_order) VALUES
('Notes',1),
('Upload Preview',2),
('LookBook',3),
('Press',4),
('Website',5),
('Sold Out',6),
('Reorder',7),
('Recommendation',8),
('Preview Files',9),
('Event',10),
('Unknown',999)
;


--
-- Add Column 'reservation_source_id' to 'reservation' Table
--
ALTER TABLE reservation
    ADD COLUMN reservation_source_id INTEGER REFERENCES reservation_source(id)
;


COMMIT WORK;
