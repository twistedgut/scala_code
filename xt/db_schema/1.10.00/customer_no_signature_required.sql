
-- Purpose: Add no signature required column to customer table

BEGIN;

ALTER TABLE customer ADD COLUMN no_signature_required boolean DEFAULT FALSE;

UPDATE customer SET no_signature_required = FALSE;

COMMIT;
