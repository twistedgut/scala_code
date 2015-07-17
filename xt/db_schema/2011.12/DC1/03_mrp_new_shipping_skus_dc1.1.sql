BEGIN;

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910000-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900000-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900000-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900000-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900000-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900000-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910001-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900001-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900001-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900001-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900001-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900001-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910002-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900002-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900002-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900002-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900002-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900002-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910003-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900003-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900003-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900003-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900003-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900003-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910004-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900004-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900004-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900004-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900004-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900004-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910005-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900005-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900005-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900005-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900005-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900005-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910008-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900008-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900008-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900008-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900008-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900008-001')
    );


COMMIT;
