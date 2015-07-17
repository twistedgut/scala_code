-- CANDO-3302: Add PayPal Icon to Finance Icons

BEGIN WORK;

INSERT INTO flag (description,flag_type_id) VALUES (
    'Paid Using PayPal',
    (
        SELECT  id
        FROM    flag_type
        WHERE   description = 'Finance'
    )
);

COMMIT WORK;
