
--CANDO-2896 Add Shipping Description for HK

BEGIN WORK;


INSERT INTO shipping.description
(name, public_name, title, public_title, short_delivery_description, long_delivery_description, estimated_delivery,
 delivery_confirmation, shipping_charge_id ) VALUES
('Premier Daytime','Premier Daytime', 'Premier Daytime', 'Daytime, 12pm-5pm, 7 days a week', 'Same day for orders placed by 10am',
 'Delivery between 12pm-5pm, seven days a week; Place your order by 10am for same-day service; Allocated 2 hour delivery window; Select a nominated date for delivery up to seven days in advance',
 'Delivery between 12pm-5pm', 'The NET-A-PORTER Premier team will contact you on the day of dispatch to arrange a two-hour delivery window',
 ( SELECT id from  shipping_charge where sku='9000324-001' )),
('Premier Evening', 'Premier Evening', 'Premier Evening', 'Evening, 5pm-9pm, Monday to Friday', 'Same day for orders placed by 2pm',
 'Delivery between 5pm-9pm, Monday to Friday; Place your order by 2pm for same-day service; Allocated 2 hour delivery window; Select a nominated date for delivery up to seven days in advance',
 'Delivery between 5pm-9pm',  'The NET-A-PORTER Premier team will contact you on the day of dispatch to arrange a two-hour delivery window',
 ( SELECT id from  shipping_charge where sku='9000323-001' ));


COMMIT WORK;

