
-- FLEX-705
--
-- Import existing restricted dates from web site
--



BEGIN;


CREATE OR REPLACE FUNCTION flex_705_import_dates(daytime_sku VARCHAR, evening_sku VARCHAR) RETURNS INTEGER AS $$
BEGIN

-- Premier Daytime
-- Christmas day
INSERT INTO shipping.delivery_date_restriction (date, shipping_charge_id, restriction_type_id) VALUES
('2012-12-25', (select id from shipping_charge where sku = daytime_sku), (select id from shipping.delivery_date_restriction_type where token = 'fulfilment_or_transit')),
('2013-12-25', (select id from shipping_charge where sku = daytime_sku), (select id from shipping.delivery_date_restriction_type where token = 'fulfilment_or_transit'));

-- Premier Evening
-- Christmas day
INSERT INTO shipping.delivery_date_restriction (date, shipping_charge_id, restriction_type_id) VALUES
('2012-12-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'fulfilment_or_transit')),
('2013-12-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'fulfilment_or_transit'));

RETURN 0;
END;
$$ LANGUAGE plpgsql;



-- NAP
select flex_705_import_dates(
    '9000211-001', -- Premier Daytime
    '9000211-002'  -- Premier Evening
);

-- MRP
select flex_705_import_dates(
    '9000213-001', -- Premier Daytime
    '9000213-002'  -- Premier Evening
);

-- OUT
select flex_705_import_dates(
    '9000215-001', -- Premier Daytime
    '9000215-002'  -- Premier Evening
);


DROP FUNCTION flex_705_import_dates(daytime_sku VARCHAR, evening_sku VARCHAR);


-- Backfill the log table
INSERT INTO shipping.delivery_date_restriction_log
    (delivery_date_restriction_id, change_reason, operator_id)
    SELECT id, 'Block out weekends and Christmas day', 1 -- 1 is Application User
        FROM shipping.delivery_date_restriction
;



COMMIT;

