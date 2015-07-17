BEGIN;

update
	product p
set
	storage_type_id=(select id from product.storage_type where name='Dematic_Flat')
from (
	select
		variant_id,
		product_id,
		sku,
		storage_type,
		classification,
		channel_name,
		sum(quantity) total_quantity
	from (
		select
			v.id variant_id,
			p.id product_id,
			v.product_id || '-' || sku_padding(v.size_id) sku,
			coalesce(q.quantity, 0) quantity,
			pst.name storage_type,
			c.classification,
			ch.name channel_name
		from
			product.storage_type pst
			join product p on (pst.id=p.storage_type_id)
			join product_channel pc on (p.id=pc.product_id)
			join channel ch on (ch.id=pc.channel_id)
			join classification c on (c.id=p.classification_id)
			join variant v on (v.product_id=p.id)
			left join quantity q on (q.variant_id=v.id)
		where
			pst.name='Flat'
		and ch.name in (
			'NET-A-PORTER.COM',
			'theOutnet.com',
			'MRPORTER.COM'
		)
		and c.classification != 'Shoes'
	) res
	group by
		variant_id,
		product_id,
		sku,
		storage_type,
		classification,
		channel_name
	having
		sum(quantity) = 0
) selector
where
	p.id=selector.product_id;

COMMIT;
