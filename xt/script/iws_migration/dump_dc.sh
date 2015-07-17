#!/bin/bash


db_user=${db_user:-postgres}
db_name=${db_name:-xtracker}
db_host=${db_host:-xtdc1-orangeuat.dave}

# Clean
rm -f ${db_name}_*.csv

# NOTES:
# we only export from "real" locations (we ignore transit places etc)
# we only export "main" and "dead" stock
# we don't export from the "single aisle" locations ('011U999A','011U999B','011U999C')

psql -U$db_user -d$db_name -h$db_host <<EOF
\f ','
\a

SELECT 'Getting location data...';
\o ${db_name}_to_invar_location_list.csv


SELECT 
       l.location as name,
       CASE las.status_id 
       WHEN 1 THEN 'main'
       WHEN 5 THEN 'sample'
       WHEN 8 THEN 'faulty'
       WHEN 10 THEN 'rtv'
       WHEN 11 THEN 'dead'
       WHEN 2 THEN 'sample'
       ELSE fs.name
       END AS allowed_status
       FROM location l
       JOIN location_allowed_status las on las.location_id = l.id 
       JOIN flow.status fs ON fs.id = las.status_id
      WHERE SUBSTRING(l.location FROM 1 FOR 2) IN ('01','02')
        AND las.status_id in (1,11)
        AND l.location not in ('011U999A','011U999B','011U999C')
      ORDER BY l.location;
;

\o
SELECT 'Getting product data...';
\o ${db_name}_to_invar_product_list.csv

SELECT id, storage_type, description, photo_link, channel
FROM (
       SELECT
       p.id,
       coalesce(st.name,'Flat') as storage_type,
       '"' || REPLACE(
               REPLACE(
                REPLACE( pa.description, E'\\\\', '' ),
                '"',E'\\\\"'),
               E'\n',' ') || '"'
        as description,
       'http://cache.net-a-porter.com/images/products/'||p.id||'/'||p.id||'_in_l.jpg' as photo_link,
       c.name as channel
       FROM product p
       LEFT JOIN product_attribute pa ON pa.product_id = p.id
       LEFT JOIN product.storage_type st ON st.id = p.storage_type_id
       LEFT JOIN channel c ON c.id = get_product_channel_id(p.id)
       WHERE c.name IS NOT NULL

UNION ALL

       SELECT
       p.id,
       'Flat' AS storage_type,
       '"' || REPLACE(
               REPLACE(
                REPLACE( p.name, E'\\\\', '' ),
                '"',E'\\\\"'),
               E'\n',' ') || '"'
        as description,
       'http://cache.net-a-porter.com/images/products/'||p.id||'/'||p.id||'_in_l.jpg' as photo_link,
       c.name as channel
       FROM voucher.product p
       LEFT JOIN channel c ON c.id = p.channel_id
       WHERE p.is_physical = true

) AS X
ORDER BY id;
;

\o
SELECT 'Getting sku quantity and location...';
\o ${db_name}_to_invar_sku_quantity_and_location_list.csv
 
SELECT sku, location, quantity, channel, allowed_status
FROM (
       SELECT
       v.product_id || '-' || sku_padding(v.size_id) as sku,
       l.location as location,
       q.quantity, 
       c.name as channel,
       CASE q.status_id 
       WHEN 1 THEN 'main'
       WHEN 5 THEN 'sample'
       WHEN 8 THEN 'faulty'
       WHEN 10 THEN 'rtv'
       WHEN 11 THEN 'dead'
       WHEN 2 THEN 'sample'
       ELSE fs.name
       END AS allowed_status
       FROM quantity q
       JOIN variant v ON v.id = q.variant_id
       JOIN flow.status fs ON fs.id=q.status_id
       JOIN location l ON l.id = q.location_id
        AND SUBSTRING(l.location FROM 1 FOR 2) IN ('01','02')
        AND l.location not in ('011U999A','011U999B','011U999C')
       JOIN channel c ON c.id = q.channel_id
       JOIN product p ON p.id = v.product_id
       WHERE q.status_id in (1,11)

UNION ALL

       SELECT
       v.voucher_product_id || '-999' as sku,
       l.location as location,
       q.quantity, 
       c.name as channel,
       'main' AS allowed_status
       FROM quantity q
       JOIN voucher.variant v ON v.id = q.variant_id
            JOIN location l ON l.id = q.location_id
             AND SUBSTRING(l.location FROM 1 FOR 2) IN ('01','02')
             AND l.location not in ('011U999A','011U999B','011U999C')
       JOIN channel c ON c.id = q.channel_id
       JOIN voucher.product p ON p.id = v.voucher_product_id
       WHERE q.status_id = 1
) AS x
ORDER BY sku, location, allowed_status
;

EOF

# Trim last line referencing the number of rows
ls ${db_name}_*.csv |xargs sed -i '$d'

echo "DONE"
