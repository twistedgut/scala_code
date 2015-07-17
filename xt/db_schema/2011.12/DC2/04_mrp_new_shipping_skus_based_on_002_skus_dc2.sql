BEGIN;
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910025-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900025-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900025-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900025-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900025-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900025-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910039-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900039-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900039-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900039-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900039-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900039-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910041-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900041-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900041-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900041-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900041-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900041-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910043-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900043-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900043-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900043-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900043-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900043-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910045-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900045-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900045-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900045-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900045-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900045-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910047-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900047-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900047-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900047-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900047-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900047-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910049-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900049-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900049-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900049-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900049-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900049-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910051-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900051-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900051-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900051-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900051-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900051-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910055-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900055-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900055-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900055-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900055-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900055-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910057-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900057-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900057-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900057-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900057-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900057-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910059-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900059-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900059-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900059-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900059-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900059-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910061-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900061-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900061-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900061-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900061-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900061-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910063-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900063-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900063-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900063-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900063-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900063-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910065-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900065-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900065-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900065-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900065-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900065-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910067-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900067-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900067-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900067-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900067-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900067-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910069-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900069-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900069-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900069-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900069-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900069-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910071-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900071-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900071-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900071-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900071-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900071-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910077-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900077-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900077-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900077-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900077-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900077-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910079-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900079-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900079-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900079-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900079-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900079-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910081-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900081-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900081-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900081-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900081-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900081-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910083-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900083-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900083-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900083-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900083-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900083-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910085-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900085-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900085-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900085-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900085-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900085-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910087-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900087-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900087-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900087-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900087-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900087-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910089-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900089-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900089-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900089-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900089-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900089-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910091-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900091-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900091-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900091-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900091-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900091-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910093-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900093-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900093-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900093-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900093-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900093-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910095-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900095-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900095-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900095-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900095-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900095-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910097-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900097-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900097-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900097-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900097-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900097-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910099-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900099-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900099-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900099-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900099-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900099-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010101-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000101-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000101-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000101-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000101-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000101-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010103-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000103-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000103-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000103-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000103-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000103-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010105-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000105-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000105-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000105-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000105-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000105-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010107-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000107-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000107-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000107-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000107-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000107-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010109-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000109-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000109-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000109-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000109-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000109-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010111-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000111-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000111-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000111-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000111-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000111-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010113-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000113-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000113-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000113-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000113-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000113-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010115-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000115-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000115-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000115-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000115-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000115-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010117-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000117-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000117-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000117-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000117-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000117-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010132-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000132-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000132-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000132-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000132-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000132-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010133-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000133-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000133-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000133-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000133-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000133-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010134-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000134-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000134-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000134-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000134-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000134-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010135-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000135-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000135-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000135-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000135-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000135-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010136-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000136-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000136-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000136-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000136-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000136-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010137-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000137-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000137-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000137-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000137-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000137-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010138-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000138-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000138-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000138-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000138-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000138-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010139-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000139-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000139-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000139-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000139-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000139-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010140-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000140-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000140-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000140-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000140-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000140-002')
    );
    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010141-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000141-002'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000141-002'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000141-002'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000141-002'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000141-002')
    );
-- WTF 2 entries for same sku?? You'll burn in hell for that
--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010206-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000206-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000206-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000206-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000206-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000206-001')
--    );
COMMIT;
