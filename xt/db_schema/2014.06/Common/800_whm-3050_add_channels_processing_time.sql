BEGIN;

    -- Add processing time for channels
    INSERT INTO sos.processing_time (channel_id, processing_time) VALUES
        ( (SELECT id FROM sos.channel WHERE api_code = 'TON'), '24:00:00');

COMMIT;
