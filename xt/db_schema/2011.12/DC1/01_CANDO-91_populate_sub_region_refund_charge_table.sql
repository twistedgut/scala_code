-- CANDO-91: Populate the 'return_sub_region_refund_charge' table

BEGIN WORK;

--
-- Add 'EU Member States'
--

-- Tax Only
INSERT INTO return_sub_region_refund_charge (sub_region_id,refund_charge_type_id,can_refund_for_return,no_charge_for_exchange) VALUES (
    ( SELECT id FROM sub_region WHERE sub_region = 'EU Member States' ),
    ( SELECT id FROM refund_charge_type WHERE type = 'Tax' ),
    TRUE,
    TRUE
);

COMMIT WORK;
