-- CANDO-345: Sales Channel Branding tables used for representing the Sales Channel
--            in Printed documents and Emails sent to the Customer

BEGIN WORK;

--
-- create the 'branding' table first which
-- will be used to hold the different kinds of branding
--
CREATE TABLE branding(
    id          SERIAL NOT NULL PRIMARY KEY,
    code        VARCHAR(50) NOT NULL,
    description VARCHAR(255) NOT NULL
);
CREATE UNIQUE INDEX idx_branding__code ON branding(code);

ALTER TABLE branding OWNER TO postgres;
GRANT ALL ON TABLE branding TO postgres;
GRANT ALL ON TABLE branding TO www;

GRANT ALL ON SEQUENCE branding_id_seq TO postgres;
GRANT ALL ON SEQUENCE branding_id_seq TO www;


--
-- create the 'channel_branding' table which
-- will be used to hold the different branding
-- for each Sales Channel
--
CREATE TABLE channel_branding (
    id              SERIAL NOT NULL PRIMARY KEY,
    channel_id      INTEGER NOT NULL REFERENCES channel(id),
    branding_id     INTEGER NOT NULL REFERENCES branding(id),
    value           VARCHAR(255) NOT NULL
);
CREATE UNIQUE INDEX idx_channel_branding__channel_id__branding_id ON channel_branding(channel_id,branding_id);

ALTER TABLE channel_branding OWNER TO postgres;
GRANT ALL ON TABLE channel_branding TO postgres;
GRANT ALL ON TABLE channel_branding TO www;

GRANT ALL ON SEQUENCE channel_branding_id_seq TO postgres;
GRANT ALL ON SEQUENCE channel_branding_id_seq TO www;


--
-- Populate the Tables
--

INSERT INTO branding (code,description) VALUES
('PF_NAME','Public Facing Name'),
('DOC_HEADING','Document Heading')
;

INSERT INTO channel_branding (channel_id,branding_id,value)
SELECT  c.id,
        b.id,
        CASE c.name
            WHEN 'theOutnet.com' THEN 'theoutnet.com'
            ELSE c.name
        END
FROM    channel c,
        branding b
ORDER BY b.id,c.id
;

COMMIT WORK;
