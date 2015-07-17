-- a view to summarise wear it with products and status (In Stock, Sold Out, Markdown)

BEGIN;

create view view_wearitwith as
select p.id as product_id, case when pa.percentage > 0 then 'Markdown' else 'Full Price' end as status,

	p11.id as slot11_pid,
	case when p11.visible is true then 'In Stock' when p11.id in (select product_id from price_adjustment) then 'Markdown' when p11.visible is false then 'Sold Out' else 'Empty' end as slot11_status,
	p12.id as slot12_pid,
	case when p12.visible is true then 'In Stock' when p12.id in (select product_id from price_adjustment) then 'Markdown' when p12.visible is false then 'Sold Out' else 'Empty' end as slot12_status,

	p21.id as slot21_pid,
	case when p21.visible is true then 'In Stock' when p21.id in (select product_id from price_adjustment) then 'Markdown' when p21.visible is false then 'Sold Out' else 'Empty' end as slot21_status,
	p22.id as slot22_pid,
	case when p22.visible is true then 'In Stock' when p22.id in (select product_id from price_adjustment) then 'Markdown' when p22.visible is false then 'Sold Out' else 'Empty' end as slot22_status,

	p31.id as slot31_pid,
	case when p31.visible is true then 'In Stock' when p31.id in (select product_id from price_adjustment) then 'Markdown' when p31.visible is false then 'Sold Out' else 'Empty' end as slot31_status,
	p32.id as slot32_pid,
	case when p32.visible is true then 'In Stock' when p32.id in (select product_id from price_adjustment) then 'Markdown' when p32.visible is false then 'Sold Out' else 'Empty' end as slot32_status

from product p
	LEFT JOIN recommended_product rp11 
		LEFT JOIN product p11 ON rp11.recommended_product_id = p11.id
	ON p.id = rp11.product_id AND rp11.type_id = 1 AND rp11.slot = 1 and rp11.sort_order = 1
	LEFT JOIN recommended_product rp12 
		LEFT JOIN product p12 ON rp12.recommended_product_id = p12.id
	ON p.id = rp12.product_id AND rp12.type_id = 1 AND rp12.slot = 1 and rp12.sort_order = 2

	LEFT JOIN recommended_product rp21 
		LEFT JOIN product p21 ON rp21.recommended_product_id = p21.id
	ON p.id = rp21.product_id AND rp21.type_id = 1 AND rp21.slot = 2 and rp21.sort_order = 1
	LEFT JOIN recommended_product rp22 
		LEFT JOIN product p22 ON rp22.recommended_product_id = p22.id
	ON p.id = rp22.product_id AND rp22.type_id = 1 AND rp22.slot = 2 and rp22.sort_order = 2

	LEFT JOIN recommended_product rp31 
		LEFT JOIN product p31 ON rp31.recommended_product_id = p31.id
	ON p.id = rp31.product_id AND rp31.type_id = 1 AND rp31.slot = 3 and rp31.sort_order = 1
	LEFT JOIN recommended_product rp32 
		LEFT JOIN product p32 ON rp32.recommended_product_id = p32.id
	ON p.id = rp32.product_id AND rp32.type_id = 1 AND rp32.slot = 3 and rp32.sort_order = 2

	LEFT JOIN price_adjustment pa ON p.id = pa.product_id AND current_timestamp BETWEEN pa.date_start AND pa.date_finish

where p.visible = true;


COMMIT;