BEGIN;

UPDATE country SET currency_id=cc.id
 FROM currency cc
 WHERE country != 'Unknown'
   AND cc.currency='USD';

COMMIT;
