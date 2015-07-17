-- Story:       CANDO-1493
-- Sub-Task:    CANDO-1802
-- Description: Add a new promotion class called 'In The Box'

BEGIN WORK;

INSERT INTO public.promotion_class (
    class
) VALUES (
    'In The Box'
);

COMMIT WORK;

