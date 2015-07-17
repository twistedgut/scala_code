
--
-- DCA-1050 - Add 'Dematic Flat' storage type.
--            This is intended to be a temporary measure, while stock is transferred
--            from the Full warehouse PRL to Dematic.
--            After all Flat stock is in Dematic, we plan to change the
--            storage type of all 'Dematic Flat' stock to just 'Flat'.
--

BEGIN;

INSERT INTO product.storage_type (name, description) VALUES
    ('Dematic Flat', 'Items that are stored flat, and only stored in the Dematic PRL');

COMMIT;
