BEGIN;

INSERT INTO business (
    name, config_section, url, show_sale_products, email_signoff
) values (
    'JIMMYCHOO.COM', 'JC', 'www.jimmychoo.com', false, 'Customer Care'
);

COMMIT;
