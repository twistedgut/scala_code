BEGIN;
  INSERT
    INTO shipment_hold_reason (
           id,
           reason
         )
  VALUES (12, 'Order placed on incorrect website'),
         (13, 'Invalid payment')
       ;
COMMIT;
