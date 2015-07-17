-- Unforuntately JimmyChoo do not use the same DDU countries as NAP so we have to channelise
-- this data.

-- See the following for more information:
-- http://confluence.net-a-porter.com/display/JCXT/Channelising+DDU+DDP
-- http://jira.nap:8084/browse/JCXT-10
BEGIN;

CREATE TABLE country_shipment_type (
        channel_id int references channel(id) not null,
        country_id int references country(id) not null,
        shipment_type_id int references shipment_type(id) not null
    );
ALTER TABLE country_shipment_type ADD CONSTRAINT channel_id_country_id_key UNIQUE (channel_id, country_id);

INSERT INTO country_shipment_type (channel_id, country_id, shipment_type_id)
SELECT  (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
        id,
        shipment_type_id
FROM    country
;

INSERT INTO country_shipment_type (channel_id, country_id, shipment_type_id)
SELECT  (SELECT id FROM channel WHERE name = 'theOutnet.com'),
        id,
        shipment_type_id
FROM    country
;

INSERT INTO country_shipment_type (channel_id, country_id, shipment_type_id)
SELECT  (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
        id,
        shipment_type_id
FROM    country
;

INSERT INTO country_shipment_type (channel_id, country_id, shipment_type_id)
SELECT  (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'),
        id,
        shipment_type_id
FROM    country
;

UPDATE country_shipment_type SET shipment_type_id = 5
WHERE channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')
AND shipment_type_id = 4;

UPDATE country_shipment_type SET shipment_type_id = 4
WHERE channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')
AND country_id IN (
  SELECT id FROM country WHERE country IN (
     'Poland', 'Portugal', 'Sweden', 'Slovenia', 'Slovakia', 'Canada', 'United States', 'United Kingdom', 'France', 'Greece', 'Hungary', 'Ireland', 'Bulgaria', 'Italy', 'Lithuania', 'Luxembourg', 'Latvia', 'Japan', 'Monaco', 'Malta', 'Puerto Rico', 'Romania', 'Singapore', 'Netherlands', 'Norway', 'Austria', 'Belgium', 'Switzerland', 'Cyprus', 'Czech Republic', 'Germany', 'Denmark', 'Estonia', 'Spain', 'Finland'
  )
)
AND shipment_type_id = 5;

ALTER TABLE country DROP COLUMN shipment_type_id;

GRANT ALL ON TABLE country_shipment_type TO postgres;
GRANT ALL ON TABLE country_shipment_type TO www;
GRANT SELECT ON TABLE country_shipment_type TO perlydev;

COMMIT;
