-- CANDO-3446: Add a Trimmed Lowercase Email Index to the
--             'customer_category_defaults' table

BEGIN WORK;

CREATE INDEX customer_category_defaults_trim_lower_email_domain_idx
    ON customer_category_defaults(trim(lower(email_domain::text)));

COMMIT WORK;
