BEGIN;

UPDATE country SET currency_id=cc.id
 FROM currency cc
 WHERE (country='Gibraltar'
    OR country='San Marino'
    OR currency_id IS NULL)
   AND cc.currency='GBP';

UPDATE country SET currency_id=cc.id
 FROM currency cc
 WHERE (country='Norway'
    OR country='Switzerland')
   AND cc.currency='EUR';

COMMIT;
