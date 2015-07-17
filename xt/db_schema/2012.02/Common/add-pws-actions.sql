-- Add recode actions to pws_action

BEGIN;

SELECT setval('pws_action_id_seq', (SELECT MAX(id) FROM public.pws_action));

INSERT INTO public.pws_action
       ( action )
       VALUES
       ('Recode Destroy'),
       ('Recode Create')
;

COMMIT;


