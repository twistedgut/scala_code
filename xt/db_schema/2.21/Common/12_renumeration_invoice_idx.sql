BEGIN;
  CREATE INDEX renumeration_invoice_nr_idx ON renumeration ( invoice_nr );
COMMIT;
