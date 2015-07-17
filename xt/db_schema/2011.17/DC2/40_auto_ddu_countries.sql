
BEGIN WORK;

-- WHM-183 - Autosend DDU acceptance terms
-- Set all countries to NON-DDU
ALTER TABLE country_shipment_type ADD COLUMN auto_ddu boolean NOT NULL DEFAULT FALSE;

-- Automatic DDU Countries ( on all channels )
-- Hong Kong
UPDATE country_shipment_type SET auto_ddu = TRUE WHERE country_id IN
    ( SELECT id FROM country WHERE country IN
        ( 'Hong Kong' )
    );

COMMIT WORK;
