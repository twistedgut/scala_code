-- This patch file addresses UPL-220; http://animal/browse/UPL-220
--
-- Action 'Shot needs colour correcting' needs to follow 'Shot taken' status

-- as a bonus, we're also correcting the capitalisation of the description of
-- the IN_COLOUR_CORRECTION state
BEGIN;

    -- SHOT TAKEN --> IN_COLOUR_CORRECTION (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='CHECK'),
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );
    -- SHOT TAKEN --> IN_COLOUR_CORRECTION (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='CHECK'),
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

    -- a late addition from Rod-Shirley:
    -- Action 'Shot needs colour correcting' also needs to follow 'Amends Retouch' status

    -- AMEND_RETOUCH --> IN_COLOUR_CORRECTION (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='AMEND_RETOUCH'),
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );
    -- AMEND_RETOUCH --> IN_COLOUR_CORRECTION (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='AMEND_RETOUCH'),
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );
    

    -- capitalisation fix
    UPDATE photography.image_status
    SET description='Shot requires colour correction'
    WHERE status='IN_COLOUR_CORRECTION'
    ;

COMMIT;
