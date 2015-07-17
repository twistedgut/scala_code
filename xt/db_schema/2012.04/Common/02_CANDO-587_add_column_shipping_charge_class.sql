-- CANDO-578: Add column Upgrade to 'shipping_charge_class' 
--            to upgrade shipping_charge_class to next one available

BEGIN WORK;

ALTER TABLE shipping_charge_class ADD COLUMN upgrade integer references shipping_charge_class(id);

UPDATE shipping_charge_class SET  upgrade =( SELECT id from shipping_charge_class where class= 'Air' )
WHERE class = 'Ground';

COMMIT WORK;
