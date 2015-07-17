-- Add 'packing_station_name' field to the 'operator_preferences' table.

BEGIN WORK;

ALTER TABLE operator_preferences ADD COLUMN packing_station_name CHARACTER VARYING(255);

COMMIT WORK;
