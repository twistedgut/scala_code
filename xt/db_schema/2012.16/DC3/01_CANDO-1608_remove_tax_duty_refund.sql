-- CANDO-15XX: Removes entries from the 'return_country_refund_charge'
--             and 'return_sub_region_refund_charge' tables as HK is DDU

BEGIN WORK;

DELETE FROM return_country_refund_charge;
DELETE FROM return_sub_region_refund_charge;

COMMIT WORK;
