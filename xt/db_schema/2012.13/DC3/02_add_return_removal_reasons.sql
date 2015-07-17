-- Add return_removal_reasons copied from DC2

BEGIN;

    INSERT INTO return_removal_reason VALUES (1, 'RTO');
    INSERT INTO return_removal_reason VALUES (2, 'Main Stock');
    INSERT INTO return_removal_reason VALUES (3, 'Jimmy Choo');
    INSERT INTO return_removal_reason VALUES (4, 'Different AWB Used');
    INSERT INTO return_removal_reason VALUES (5, 'Other');

COMMIT;
