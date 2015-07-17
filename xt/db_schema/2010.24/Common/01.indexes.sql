-- discovered while investigating Hudson slowness
BEGIN;
    -- http://confluence.net-a-porter.com/display/BAK/SQL+Queries+to+Optimise#SQLQueriestoOptimise-SQLNo69
    CREATE INDEX idx_shipment_delivered ON public.shipment(delivered);
    CREATE INDEX idx_variant__type_id ON public.variant(type_id);
    CREATE INDEX idx_public_product_channel__product_id ON public.product_channel(product_id);
    CREATE INDEX idx_stock_transfer__type_id ON public.stock_transfer(type_id);
    CREATE INDEX link_stock_transfer__stock_transfer_id ON public.link_stock_transfer__shipment(stock_transfer_id);

    -- http://confluence.net-a-porter.com/display/BAK/SQL+Queries+to+Optimise#SQLQueriestoOptimise-SQLNo69
    CREATE INDEX idx_quantity__location_id ON public.quantity(location_id); 
    CREATE INDEX idx_stock_order_item__variant_id ON public.stock_order_item(variant_id); 
COMMIT;
