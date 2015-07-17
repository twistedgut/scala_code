-- GV-373: Add new Finance Flag Icon for Virtual Vouchers which fail Settle Payment

BEGIN WORK;

-- Reset the Sequence
SELECT setval(
    'flag_id_seq',
    ( SELECT MAX(id) FROM flag )
)
;

INSERT INTO flag ( description, flag_type_id ) VALUES (
    'Virtual Voucher Payment Failure',
    (
        SELECT  id
        FROM    flag_type
        WHERE   description = 'Finance'
    )
)
;

COMMIT WORK;
