BEGIN;

    -- Need to update the primary key on the log table to include channel.
    -- Otherwise tests do weird things.
    -- Shouldn't every affect anything in production as we shouldn't have the same variant in
    -- multiple channels at the same time (and if we do, the logs is the wrong place to be catching this!)

    ALTER TABLE log_location DROP CONSTRAINT log_new_location_pkey;
    ALTER TABLE log_location ADD CONSTRAINT log_new_location_pkey PRIMARY KEY (variant_id, location_id, channel_id, date);

COMMIT;
