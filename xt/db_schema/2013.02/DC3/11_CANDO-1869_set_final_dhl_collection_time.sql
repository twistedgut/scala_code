--
-- CANDO-1869
--
-- Last pickup time for DHL Express is 8pm in DC3
--

BEGIN WORK;

UPDATE carrier
   SET last_pickup_daytime = '20:00:00'
 WHERE name = 'DHL Express'
     ;

COMMIT WORK;
