

use mrp_am;

start transaction;

-- WHM-3546 : Problem with zero stock levels in the web db
-- The issue is down to missing stock_location rows for several skus
-- The following creates these rows

insert into stock_location (
        id,
        sku,
        no_in_stock,
        is_sellable,
        is_manually_set,
        version,
        created_dts,
        created_by,
        last_updated_dts,
        last_updated_by
    ) values
    ('DC2', '166112-1475', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '166116-1010', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '167179-815', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '167183-815', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '173904-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '173905-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '173906-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '173907-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '174904-1150', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '177035-1475', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '177047-1475', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '185510-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '185511-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '197740-889', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '197740-890', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '197740-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '198067-889', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '198067-890', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '198067-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '198068-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '198358-889', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '198358-890', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '198358-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '312274-751', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '313148-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '315817-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '316727-049', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '318010-1475', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '318012-1475', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '320024-889', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '320024-890', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '320024-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '320025-889', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '320025-890', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '320025-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '320026-889', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '320026-890', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '320026-891', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '331606-1150', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), ''),
    ('DC2', '355999-1150', '0', 'T', 'F', 0, now(), 'XTRACKER', now(), '');


commit;
