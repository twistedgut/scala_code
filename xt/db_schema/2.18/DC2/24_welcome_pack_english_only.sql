BEGIN;

DELETE from country_promotion_type_welcome_pack WHERE country_id != (SELECT id FROM country WHERE code ='GB');

COMMIT;

