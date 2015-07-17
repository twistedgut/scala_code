-- CANDO-8228: Add last-updated timestamp to orders.payment

BEGIN WORK;

ALTER
TABLE orders.payment
  ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    ;

COMMIT WORK;
