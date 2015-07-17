-- CANDO-8228: Add last-updated timestamp to pre_order

BEGIN WORK;

ALTER
TABLE pre_order
  ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    ;

COMMIT WORK;
