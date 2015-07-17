-- CANDO-8641: Add Klarna Icon to Finance Icons

BEGIN WORK;

INSERT INTO flag (description,flag_type_id) VALUES (
    'Paid Using Klarna',
    (
        SELECT  id
        FROM    flag_type
        WHERE   description = 'Finance'
    )
);

COMMIT WORK;
