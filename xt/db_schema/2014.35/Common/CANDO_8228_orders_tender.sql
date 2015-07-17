-- CANDO-8228: Add last-updated timestamp to orders.tender

BEGIN WORK;

ALTER
TABLE orders.tender
  ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    ;


COMMIT WORK;
