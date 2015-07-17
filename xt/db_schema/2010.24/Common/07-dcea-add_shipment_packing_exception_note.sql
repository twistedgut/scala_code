BEGIN;

    SELECT setval('note_type_id_seq', (SELECT MAX(id) FROM public.note_type)+1);
    INSERT INTO note_type ( code, description ) VALUES (
        'QLC', 'Quality Control' );

COMMIT;
