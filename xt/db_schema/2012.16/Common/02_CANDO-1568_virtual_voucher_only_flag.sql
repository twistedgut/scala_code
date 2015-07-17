--CANDO-1568 : Virtual Voucher only flag
--
-- Add the new Finance Flag
--

BEGIN WORK;

INSERT INTO flag ( description, flag_type_id ) VALUES (
    'Virtual Voucher Only',
    (
        SELECT  id
        FROM    flag_type
        WHERE   description = 'Finance'
    )
);


COMMIT WORK;

