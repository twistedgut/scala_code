-- make fit_notes and style_notes text, to match with fulcrum and prevent
-- errors when receiving updates about products with long text in there

BEGIN;

alter table product_attribute alter column fit_notes type text;
alter table product_attribute alter column style_notes type text;

COMMIT;
