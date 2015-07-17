BEGIN;

CREATE UNIQUE INDEX uix_country_tax ON tax_rule_value (tax_rule_id, country_id);

COMMIT;
