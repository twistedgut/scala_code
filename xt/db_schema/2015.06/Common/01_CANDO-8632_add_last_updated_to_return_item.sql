-- CANDO-8632: Add 'last_updated' column to 'return_item' table and
--             add a Trigger to populate the 'last_updated'
--             column whenever an Update occurs, this will
--             use the existing function 'last_updated_func'

BEGIN WORK;

ALTER TABLE return_item
    ADD COLUMN   last_updated TIMESTAMP WITH TIME ZONE,
    -- setting the DEFAULT this way means that the new column on
    -- existing records will be left blank allowing them to be
    -- back-filled later so as not to need down-time
    ALTER COLUMN last_updated SET DEFAULT now()
;

CREATE TRIGGER public_return_item_last_updated_tr BEFORE UPDATE ON public.return_item
    FOR EACH ROW EXECUTE PROCEDURE last_updated_func()
;

COMMIT WORK;
