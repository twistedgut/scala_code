-- WHM-3050: Consider channel when calculating processing times

BEGIN;

-- Create channel table
CREATE TABLE sos.channel (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    api_code TEXT UNIQUE NOT NULL
);

INSERT INTO sos.channel (name, api_code) VALUES
    ('NET-A-PORTER.COM', 'NAP'),
    ('MRPORTER.COM', 'MRP'),
    ('theOutnet.com', 'TON'),
    ('JIMMYCHOO.COM', 'JC');

ALTER TABLE sos.channel OWNER TO www;

-- processing_time table:

-- Add new column and add unique constraint to others
ALTER TABLE sos.processing_time ADD COLUMN channel_id INTEGER UNIQUE REFERENCES sos.channel(id);
ALTER TABLE sos.processing_time ADD UNIQUE (class_id);
ALTER TABLE sos.processing_time ADD UNIQUE (country_id);
ALTER TABLE sos.processing_time ADD UNIQUE (region_id);
ALTER TABLE sos.processing_time ADD UNIQUE (class_attribute_id);

COMMIT;
