--
-- ECO-1305
--
-- bring season conversion rates into line with web app DB
--
-- and now, set the revised rates
--

BEGIN WORK;

UPDATE season_conversion_rate
   SET conversion_rate = 0.781
 WHERE season_id = 31
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.78
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 1.856
 WHERE season_id = 31
   AND source_currency_id = 1
   AND destination_currency_id = 2
   AND conversion_rate = 1.86
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.539
 WHERE season_id = 31
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.54
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.847
 WHERE season_id = 32
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.85
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.8475
 WHERE season_id = 40
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.83
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 1.18
 WHERE season_id = 40
   AND source_currency_id = 1
   AND destination_currency_id = 3
   AND conversion_rate = 1.2
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.753
 WHERE season_id = 40
   AND source_currency_id = 2
   AND destination_currency_id = 3
   AND conversion_rate = 0.77
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.6373
 WHERE season_id = 40
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.65
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.8475
 WHERE season_id = 41
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.83
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 1.18
 WHERE season_id = 41
   AND source_currency_id = 1
   AND destination_currency_id = 3
   AND conversion_rate = 1.2
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.6373
 WHERE season_id = 41
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.65
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.753
 WHERE season_id = 41
   AND source_currency_id = 2
   AND destination_currency_id = 3
   AND conversion_rate = 0.77
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.8475
 WHERE season_id = 42
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.83
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 1.18
 WHERE season_id = 42
   AND source_currency_id = 1
   AND destination_currency_id = 3
   AND conversion_rate = 1.2
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.6373
 WHERE season_id = 42
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.65
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.753
 WHERE season_id = 42
   AND source_currency_id = 2
   AND destination_currency_id = 3
   AND conversion_rate = 0.77
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.8475
 WHERE season_id = 45
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.85
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.6452
 WHERE season_id = 45
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.65
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.8475
 WHERE season_id = 46
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.85
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.6452
 WHERE season_id = 46
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.65
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.8403
 WHERE season_id = 47
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.84
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.6452
 WHERE season_id = 47
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.65
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.8403
 WHERE season_id = 48
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.84
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.6452
 WHERE season_id = 48
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.65
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.8333
 WHERE season_id = 49
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.83
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.6452
 WHERE season_id = 49
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.65
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.8333
 WHERE season_id = 50
   AND source_currency_id = 3
   AND destination_currency_id = 1
   AND conversion_rate = 0.83
     ;

UPDATE season_conversion_rate
   SET conversion_rate = 0.6452
 WHERE season_id = 50
   AND source_currency_id = 2
   AND destination_currency_id = 1
   AND conversion_rate = 0.65
     ;

COMMIT WORK;
