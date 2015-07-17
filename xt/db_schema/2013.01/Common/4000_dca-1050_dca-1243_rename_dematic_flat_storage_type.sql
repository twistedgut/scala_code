
--
-- DCA-1050 DCA-1243 - Rename 'Dematic Flat' storage type to 'Dematic_Flat'.
--      Because the XT config doesn't allow spaces in key names
--

BEGIN;

UPDATE product.storage_type SET name = 'Dematic_Flat' WHERE name = 'Dematic Flat';

COMMIT;
