-- CANDO-8228: Add last-updated timestamp to reservation

BEGIN WORK;

ALTER
TABLE reservation
  ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    ;

COMMIT WORK;
