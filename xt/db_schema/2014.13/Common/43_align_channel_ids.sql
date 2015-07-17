BEGIN;

    -- Align the sos channel ids so they match the XT ones

    -- Have to remove Outnet processing-time so that we can change the channel-id
    DELETE FROM sos.processing_time WHERE channel_id IS NOT NULL;

    -- Make all the current id values much higher so ensure we do not get conflicts when
    -- we re-number them below
    UPDATE sos.channel sc
        SET id = id +100;

    UPDATE sos.channel sc
        SET id = (SELECT id FROM public.channel pc WHERE pc.name = sc.name);

    -- Now we can put the Outnet back :)
    INSERT INTO sos.processing_time (channel_id, processing_time)
        VALUES (
            (SELECT id FROM sos.channel WHERE name = 'theOutnet.com'),
            '24:00:00'
        );

COMMIT;