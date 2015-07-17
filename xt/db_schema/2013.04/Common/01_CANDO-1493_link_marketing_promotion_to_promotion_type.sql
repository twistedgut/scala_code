-- Story:       CANDO-1493
-- Sub-Task:    CANDO-1800
-- Description: Add a link from the marketing_promotion table to the
--              promotion_type table, so promotions can be "weighted".

BEGIN WORK;

-- The column can be null, as not all promotions are weighted.
ALTER TABLE public.marketing_promotion
ADD COLUMN promotion_type_id integer REFERENCES public.promotion_type(id);

COMMIT WORK;

