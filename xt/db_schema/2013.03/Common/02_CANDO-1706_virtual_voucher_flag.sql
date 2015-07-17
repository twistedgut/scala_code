
--CANDO-1706 : Virtual Voucher flag
--
-- Update Finance Flag
--

BEGIN WORK;

UPDATE flag SET description='Virtual Voucher'
WHERE description='Virtual Voucher Only';


COMMIT WORK;

