
begin;

update product_channel
    set cancelled='f'
where
    cancelled='t' and (product_id, channel_id) in (
        select
            so.product_id,
            po.channel_id
        from
            purchase_order po,
            stock_order so
        where
            po.id     = so.purchase_order_id
        and po.cancel = 'f'
        and so.cancel = 'f'
    );

commit;
