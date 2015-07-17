--
-- define Vertex taxation areas for North America
--

BEGIN WORK;

CREATE TABLE vertex_area (
    country   VARCHAR(255) NOT NULL,
    county    VARCHAR(255),
    UNIQUE (country,county)
);

ALTER TABLE vertex_area OWNER             TO postgres;
GRANT ALL ON TABLE vertex_area            TO postgres;
GRANT ALL ON TABLE vertex_area            TO www;

COMMIT WORK;
