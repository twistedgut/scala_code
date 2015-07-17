BEGIN;
CREATE OR REPLACE VIEW mega_product AS

SELECT
p.id,
pa.name,
se.season, 
act.act,
dept.department, 
d.designer, 
pt.product_type, 
pa.description,
pa.designer_colour,
pa.designer_colour_code, 
c.colour, 
p.style_number,
p.legacy_sku,
bool_or(pc.live) as live

FROM product p 

join product_channel pc on (p.id = pc.product_id)
join season se on(p.season_id = se.id)
join designer d on (p.designer_id = d.id)
join product_type pt on ( p.product_type_id = pt.id )
join colour c on (p.colour_id = c.id )
left join product_attribute pa on ( p.id = pa.product_id )
join season_act act on (pa.act_id = act.id) 
join product_department dept on (pa.product_department_id = dept.id)
join variant v on (v.product_id = p.id)
join variant_type vt on (v.type_id = vt.id)

GROUP BY  p.id,
pa.name, 
se.season, 
act.act, 
dept.department, 
d.designer, 
pt.product_type, 
pa.description, 
pa.designer_colour, 
pa.designer_colour_code, 
c.colour, 
p.style_number, 
p.legacy_sku, 
pc.live

UNION

SELECT vp.id, 
    vp.name,
    'Continuity' as season, 
    'Unknown' as act,
    'Unknown' as department,
    'Unknown' as designer,
    'Unknown' as product_type,
    'Gift Voucher' as description,
    'N/A' as designer_colour,
    'N/A' as designer_colour_code, 
    'N/A' as colour,
    'Gift Voucher' as style_number,
    '9999' as legacy_sku,
    case when 
        vp.upload_date is not null 
        then true    
        else false 
    end as live
FROM 
voucher.product vp;

GRANT SELECT ON mega_product to www;
COMMIT;
