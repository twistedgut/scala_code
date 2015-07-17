-- Purpose:


BEGIN;

-- renaming new product_attribute field
alter table product_attribute rename column fit_notes_required to use_fit_notes;

COMMIT;
