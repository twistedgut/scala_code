-- CANDO-91: Populate the 'return_country_refund_charge' table

BEGIN WORK;

--
-- Add 'United States'
--

-- Tax Only
INSERT INTO return_country_refund_charge (country_id,refund_charge_type_id,can_refund_for_return,no_charge_for_exchange) VALUES (
    ( SELECT id FROM country WHERE country = 'United States' ),
    ( SELECT id FROM refund_charge_type WHERE type = 'Tax' ),
    TRUE,
    TRUE
);

--
-- Add 'Canada'
--

-- Tax
INSERT INTO return_country_refund_charge (country_id,refund_charge_type_id,can_refund_for_return,no_charge_for_exchange) VALUES (
    ( SELECT id FROM country WHERE country = 'Canada' ),
    ( SELECT id FROM refund_charge_type WHERE type = 'Tax' ),
    TRUE,
    TRUE
);

-- Duty
INSERT INTO return_country_refund_charge (country_id,refund_charge_type_id,can_refund_for_return,no_charge_for_exchange) VALUES (
    ( SELECT id FROM country WHERE country = 'Canada' ),
    ( SELECT id FROM refund_charge_type WHERE type = 'Duty' ),
    TRUE,
    TRUE
);

COMMIT WORK;
