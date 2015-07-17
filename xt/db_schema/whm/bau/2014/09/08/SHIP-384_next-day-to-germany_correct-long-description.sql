--
-- SHIP-384: correct the long_delivery_description
--

BEGIN;

  UPDATE shipping.description
  SET    long_delivery_description = '&bull;Delivery between 9am-5pm, Monday to Friday <br />&bull;  Orders placed before 4pm CEST Monday to Friday will be delivered next business day <br  />&bull; Orders placed after 4pm CEST on Friday, or on Saturday or on Sunday will be delivered on Tuesday'
  WHERE  shipping_charge_id        = (SELECT id FROM shipping_charge WHERE sku = '9000524-004');

COMMIT;

