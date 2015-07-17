-- changes to update the icons used for Sample State information icon(s),
-- alter a name, and add a new state
BEGIN;

    UPDATE photography.sample_state
    SET icon='/images/icons/exclamation.png',
        name='Missing'
    WHERE name='Not Seen'
    ;

    UPDATE photography.sample_state
    SET icon='/images/icons/accept.png'
    WHERE name='Received'
    ;

    INSERT INTO photography.sample_state (name, icon)
    VALUES('Incorrect', '/images/icons/error.png')
    ;

COMMIT;
