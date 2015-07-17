
-- FLEX-705
--
-- Import existing restricted dates from web site
--



BEGIN;


CREATE OR REPLACE FUNCTION flex_705_import_dates(daytime_sku VARCHAR, evening_sku VARCHAR) RETURNS INTEGER AS $$
BEGIN

-- -- Premier Daytime
-- Christmas day
INSERT INTO shipping.delivery_date_restriction (date, shipping_charge_id, restriction_type_id) VALUES
('2012-12-25', (select id from shipping_charge where sku = daytime_sku), (select id from shipping.delivery_date_restriction_type where token = 'fulfilment_or_transit')),
('2013-12-25', (select id from shipping_charge where sku = daytime_sku), (select id from shipping.delivery_date_restriction_type where token = 'fulfilment_or_transit'));



-- -- Premier Evening
-- Christmas day
INSERT INTO shipping.delivery_date_restriction (date, shipping_charge_id, restriction_type_id) VALUES
('2012-12-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'fulfilment_or_transit')),
('2013-12-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'fulfilment_or_transit'));

-- Weekends
INSERT INTO shipping.delivery_date_restriction (date, shipping_charge_id, restriction_type_id) VALUES
('2012-01-21', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-01-22', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-01-28', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-01-29', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-02-04', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-02-05', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-02-11', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-02-12', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-02-18', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-02-19', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-02-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-02-26', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-03-03', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-03-04', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-03-10', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-03-11', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-03-17', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-03-18', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-03-24', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-03-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-03-31', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-04-01', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-04-07', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-04-08', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-04-14', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-04-15', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-04-21', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-04-22', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-04-28', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-04-29', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-05-05', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-05-06', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-05-12', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-05-13', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-05-19', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-05-20', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-05-26', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-05-27', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-06-02', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-06-03', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-06-09', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-06-10', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-06-16', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-06-17', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-06-23', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-06-24', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-06-30', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-07-01', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-07-07', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-07-08', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-07-14', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-07-15', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-07-21', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-07-22', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-07-28', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-07-29', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-08-04', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-08-05', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-08-11', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-08-12', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-08-18', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-08-19', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-08-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-08-26', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-01', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-02', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-08', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-09', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-15', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-16', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-22', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-23', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-29', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-09-30', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-10-06', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-10-07', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-10-13', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-10-14', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-10-20', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-10-21', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-10-27', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-10-28', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-11-03', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-11-04', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-11-10', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-11-11', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-11-17', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-11-18', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-11-24', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-11-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-01', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-02', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-08', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-09', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-15', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-16', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-22', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-23', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-29', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2012-12-30', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-01-05', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-01-06', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-01-12', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-01-13', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-01-19', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-01-20', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-01-26', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-01-27', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-02-02', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-02-03', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-02-09', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-02-10', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-02-16', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-02-17', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-02-23', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-02-24', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-02', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-03', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-09', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-10', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-16', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-17', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-23', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-24', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-30', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-03-31', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-04-06', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-04-07', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-04-13', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-04-14', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-04-20', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-04-21', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-04-27', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-04-28', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-05-04', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-05-05', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-05-11', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-05-12', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-05-18', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-05-19', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-05-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-05-26', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-01', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-02', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-08', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-09', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-15', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-16', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-22', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-23', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-29', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-06-30', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-07-06', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-07-07', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-07-13', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-07-14', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-07-20', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-07-21', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-07-27', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-07-28', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-08-03', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-08-04', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-08-10', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-08-11', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-08-17', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-08-18', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-08-24', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-08-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-08-31', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-09-01', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-09-07', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-09-08', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-09-14', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-09-15', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-09-21', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-09-22', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-09-28', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-09-29', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-10-05', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-10-06', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-10-12', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-10-13', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-10-19', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-10-20', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-10-26', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-10-27', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-11-02', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-11-03', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-11-09', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-11-10', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-11-16', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-11-17', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-11-23', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-11-24', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-11-30', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-01', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-07', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-08', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-14', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-15', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-21', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-22', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-25', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-28', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery')),
('2013-12-29', (select id from shipping_charge where sku = evening_sku), (select id from shipping.delivery_date_restriction_type where token = 'delivery'));

RETURN 0;
END;
$$ LANGUAGE plpgsql;



-- NAP
select flex_705_import_dates(
    '9000210-001', -- Premier Daytime
    '9000210-002'  -- Premier Evening
);

-- MRP
select flex_705_import_dates(
    '9000212-001', -- Premier Daytime
    '9000212-002'  -- Premier Evening
);

-- OUT
select flex_705_import_dates(
    '9000214-001', -- Premier Daytime
    '9000214-002'  -- Premier Evening
);


DROP FUNCTION flex_705_import_dates(daytime_sku VARCHAR, evening_sku VARCHAR);


-- Backfill the log table
INSERT INTO shipping.delivery_date_restriction_log
    (delivery_date_restriction_id, change_reason, operator_id)
    SELECT id, 'Block out weekends and Christmas day', 1 -- 1 is Application User
        FROM shipping.delivery_date_restriction
;


COMMIT;

