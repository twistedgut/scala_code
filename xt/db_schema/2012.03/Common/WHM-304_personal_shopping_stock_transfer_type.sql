-- WHM-304
-- Add a new stock transfer type 'Personal Shopping'

BEGIN work;

    SELECT setval('stock_transfer_type_id_seq',
        (SELECT max(id) FROM public.stock_transfer_type)
    );

    INSERT INTO public.stock_transfer_type(type)
        VALUES('Personal Shopping');

COMMIT;
