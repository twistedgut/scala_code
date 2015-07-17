--CANDO-2881 : Add Premier Shipping SKUS's for HK

BEGIN WORK;


INSERT INTO shipping_charge
( sku, description, charge, currency_id, flat_rate, class_id, channel_id, latest_nominated_dispatch_daytime,premier_routing_id,is_customer_facing) VALUES
('9000324-001','Premier Daytime',90.00,(SELECT id FROM currency WHERE currency='HKD'),true,
      (SELECT id FROM shipping_charge_class WHERE class='Same Day'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'), '11:00:00',
      (SELECT id FROM premier_routing WHERE code = 'D'), TRUE ),
('9000323-001','Premier Evening',90.00,(SELECT id FROM currency WHERE currency='HKD'),true,
      (SELECT id FROM shipping_charge_class WHERE class='Same Day'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'), '15:00:00',
      (SELECT id FROM premier_routing WHERE code = 'E'), TRUE ),
('9000320-001','FAST TRACK: Premier Anytime',90.00,(SELECT id FROM currency WHERE currency='HKD'),true,
      (SELECT id FROM shipping_charge_class WHERE class='Same Day'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'), NULL,
      (SELECT id FROM premier_routing WHERE code = 'A'), FALSE );



COMMIT WORK;
