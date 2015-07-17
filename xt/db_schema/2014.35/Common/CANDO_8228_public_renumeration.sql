-- CANDO-8228: Add last-updated timestamp to renumeration

BEGIN WORK;

ALTER
TABLE renumeration
  ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    ;

COMMIT WORK;
