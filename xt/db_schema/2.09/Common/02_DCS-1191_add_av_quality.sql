-- Add 'av_quality_rating' to 'shipment' table

BEGIN WORK;

ALTER TABLE shipment ADD COLUMN av_quality_rating CHARACTER VARYING(30);

COMMIT WORK;
