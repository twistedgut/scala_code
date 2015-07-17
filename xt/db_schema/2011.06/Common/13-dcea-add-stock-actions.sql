-- Add recode actions to stock_atcion

ROLLBACK;BEGIN;

INSERT INTO public.stock_action
       ( action )
       VALUES
       ('Recode Destroy'),
       ('Recode Create')
;

COMMIT;

