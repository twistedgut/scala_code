BEGIN;

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910012-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900012-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900012-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900012-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900012-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900012-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910013-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900013-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900013-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900013-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900013-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900013-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910014-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900014-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900014-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900014-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900014-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900014-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910025-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900025-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900025-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900025-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900025-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900025-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910026-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900026-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900026-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900026-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900026-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900026-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910027-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900027-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900027-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900027-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900027-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900027-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910028-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900028-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900028-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900028-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900028-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900028-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910029-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900029-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900029-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900029-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900029-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900029-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910030-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900030-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900030-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900030-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900030-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900030-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910031-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900031-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900031-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900031-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900031-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900031-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910032-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900032-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900032-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900032-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900032-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900032-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910033-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900033-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900033-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900033-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900033-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900033-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910034-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900034-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900034-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900034-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900034-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900034-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910035-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900035-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900035-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900035-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900035-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900035-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910036-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900036-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900036-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900036-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900036-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900036-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910038-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900038-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900038-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900038-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900038-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900038-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910039-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900039-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900039-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900039-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900039-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900039-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910040-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900040-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900040-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900040-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900040-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900040-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910041-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900041-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900041-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900041-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900041-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900041-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910042-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900042-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900042-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900042-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900042-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900042-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910043-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900043-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900043-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900043-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900043-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900043-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910044-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900044-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900044-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900044-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900044-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900044-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910045-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900045-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900045-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900045-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900045-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900045-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910046-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900046-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900046-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900046-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900046-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900046-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910047-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900047-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900047-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900047-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900047-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900047-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910048-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900048-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900048-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900048-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900048-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900048-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910049-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900049-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900049-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900049-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900049-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900049-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910050-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900050-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900050-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900050-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900050-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900050-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910051-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900051-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900051-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900051-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900051-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900051-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910052-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900052-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900052-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900052-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900052-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900052-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910054-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900054-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900054-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900054-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900054-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900054-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910055-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900055-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900055-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900055-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900055-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900055-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910056-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900056-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900056-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900056-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900056-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900056-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910057-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900057-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900057-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900057-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900057-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900057-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910058-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900058-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900058-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900058-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900058-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900058-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910059-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900059-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900059-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900059-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900059-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900059-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910060-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900060-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900060-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900060-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900060-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900060-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910061-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900061-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900061-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900061-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900061-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900061-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910062-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900062-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900062-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900062-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900062-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900062-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910063-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900063-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900063-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900063-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900063-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900063-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910064-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900064-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900064-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900064-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900064-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900064-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910065-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900065-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900065-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900065-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900065-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900065-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910066-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900066-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900066-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900066-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900066-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900066-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910067-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900067-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900067-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900067-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900067-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900067-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910068-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900068-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900068-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900068-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900068-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900068-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910069-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900069-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900069-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900069-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900069-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900069-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910070-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900070-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900070-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900070-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900070-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900070-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910071-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900071-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900071-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900071-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900071-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900071-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910072-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900072-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900072-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900072-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900072-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900072-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910074-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900074-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900074-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900074-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900074-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900074-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910076-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900076-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900076-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900076-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900076-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900076-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910077-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900077-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900077-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900077-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900077-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900077-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910078-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900078-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900078-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900078-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900078-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900078-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910079-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900079-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900079-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900079-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900079-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900079-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910080-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900080-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900080-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900080-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900080-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900080-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910081-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900081-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900081-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900081-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900081-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900081-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910082-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900082-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900082-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900082-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900082-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900082-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910083-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900083-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900083-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900083-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900083-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900083-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910084-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900084-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900084-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900084-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900084-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900084-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910085-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900085-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900085-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900085-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900085-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900085-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910086-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900086-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900086-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900086-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900086-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900086-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910087-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900087-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900087-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900087-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900087-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900087-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910088-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900088-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900088-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900088-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900088-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900088-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910089-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900089-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900089-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900089-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900089-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900089-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910090-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900090-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900090-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900090-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900090-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900090-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910091-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900091-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900091-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900091-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900091-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900091-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910092-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900092-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900092-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900092-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900092-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900092-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910093-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900093-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900093-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900093-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900093-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900093-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910094-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900094-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900094-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900094-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900094-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900094-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910095-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900095-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900095-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900095-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900095-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900095-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910096-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900096-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900096-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900096-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900096-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900096-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910097-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900097-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900097-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900097-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900097-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900097-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '910098-001',
        ( SELECT description FROM shipping_charge WHERE sku = '900098-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '900098-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '900098-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900098-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '900098-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '910099-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '900099-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '900099-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '900099-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '900099-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '900099-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010100-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000100-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000100-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000100-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000100-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000100-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010101-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000101-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000101-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000101-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000101-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000101-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010102-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000102-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000102-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000102-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000102-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000102-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010103-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000103-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000103-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000103-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000103-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000103-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010104-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000104-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000104-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000104-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000104-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000104-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010105-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000105-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000105-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000105-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000105-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000105-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010106-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000106-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000106-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000106-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000106-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000106-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010107-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000107-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000107-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000107-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000107-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000107-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010108-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000108-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000108-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000108-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000108-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000108-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010109-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000109-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000109-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000109-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000109-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000109-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010110-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000110-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000110-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000110-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000110-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000110-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010111-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000111-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000111-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000111-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000111-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000111-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010112-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000112-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000112-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000112-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000112-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000112-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010113-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000113-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000113-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000113-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000113-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000113-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010114-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000114-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000114-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000114-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000114-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000114-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010115-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000115-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000115-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000115-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000115-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000115-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010116-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000116-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000116-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000116-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000116-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000116-001')
    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010117-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000117-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000117-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000117-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000117-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000117-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010132-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000132-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000132-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000132-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000132-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000132-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010133-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000133-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000133-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000133-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000133-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000133-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010134-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000134-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000134-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000134-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000134-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000134-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010135-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000135-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000135-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000135-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000135-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000135-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010136-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000136-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000136-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000136-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000136-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000136-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010137-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000137-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000137-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000137-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000137-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000137-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010138-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000138-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000138-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000138-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000138-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000138-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010139-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000139-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000139-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000139-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000139-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000139-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010140-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000140-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000140-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000140-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000140-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000140-001')
--    );

--    INSERT INTO public.shipping_charge (
--        sku, description, charge, currency_id, flat_rate, class_id
--    ) VALUES (
--        '9010141-001',
--        ( SELECT description FROM shipping_charge WHERE sku = '9000141-001'),
--        ( SELECT charge FROM shipping_charge WHERE sku = '9000141-001'),
--        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000141-001'),
--        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000141-001'),
--        ( SELECT class_id FROM shipping_charge WHERE sku = '9000141-001')
--    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010203-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000203-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000203-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000203-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000203-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000203-001')
    );

    INSERT INTO public.shipping_charge (
        sku, description, charge, currency_id, flat_rate, class_id
    ) VALUES (
        '9010205-001',
        ( SELECT description FROM shipping_charge WHERE sku = '9000205-001'),
        ( SELECT charge FROM shipping_charge WHERE sku = '9000205-001'),
        ( SELECT currency_id FROM shipping_charge WHERE sku = '9000205-001'),
        ( SELECT flat_rate FROM shipping_charge WHERE sku = '9000205-001'),
        ( SELECT class_id FROM shipping_charge WHERE sku = '9000205-001')
    );

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
