-- CANDO-8228: Add last-updated timestamp to renumeration_item

BEGIN WORK;

ALTER
TABLE renumeration_item
  ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    ;

COMMIT WORK;
