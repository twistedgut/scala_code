-- Mapping table for Returns QC & Putaway Returns, to map a location zone to another location zone

BEGIN WORK;

CREATE TABLE location_zone_to_zone_mapping (
    zone_from CHARACTER(4),
    zone_to CHARACTER(4),
    channel_id integer REFERENCES channel(id),
    constraint zone_to_zone UNIQUE (zone_from,zone_to,channel_id)
);
CREATE INDEX zone_from_idx ON location_zone_to_zone_mapping(zone_from);

ALTER TABLE location_zone_to_zone_mapping OWNER TO postgres;
GRANT ALL ON TABLE location_zone_to_zone_mapping TO postgres;
GRANT ALL ON TABLE location_zone_to_zone_mapping TO www;

COMMIT WORK;
