-- Make a couple of large in-code selects much simpler by using a view in the database
BEGIN;

    CREATE VIEW invoice_item_information
    AS
        SELECT  ri.id,
                ri.id                   AS renumeration_item_id,
                -- it would be nice to lose "id" totally and only have "renumeration_item_id" for clarity"
                -- but we don't know what knock on effect this will have, and the Vertex project
                -- is running late enough without adding to the confusion
                ri.renumeration_id,
                ri.shipment_item_id,
                ri.unit_price,
                ri.tax,
                ri.duty,
                v.id as variant,
                v.size_id,
                v.legacy_sku,
                v.product_id,
                s.size,
                d.designer,
                pa.name,
                pc.classification
         FROM   renumeration_item ri,
                shipment_item si,
                variant v,
                size s,
                product p,
                designer d,
                product_attribute pa,
                classification pc
        WHERE   ri.shipment_item_id     = si.id
          AND   si.variant_id           = v.id
          AND   v.size_id               = s.id
          AND   v.product_id            = p.id
          AND   p.designer_id           = d.id
          AND   v.product_id            = pa.product_id
          AND   p.classification_id     = pc.id
    ;

    CREATE VIEW shipment_item_information
    AS
        SELECT  si.id,
                si.id                       AS shipment_item_id,
                -- it would be nice to lose "id" totally and only have "shipment_item_id" for clarity"
                -- but we don't know what knock on effect this will have, and the Vertex project
                -- is running late enough without adding to the confusion
                si.shipment_id,
                si.variant_id,
                si.unit_price,
                si.tax,
                si.duty,
                si.shipment_item_status_id,
                si.special_order_flag,
                sis.status,
                v.size_id,
                lpad( v.size_id, 3, 0 ) as sku_size,
                v.designer_size_id,
                v.legacy_sku,
                v.product_id,
                s.size,
                s2.size as designer_size,
                d.designer,
                pa.name,
                ss.short_name,
                c.colour,
                pc.classification
          FROM  shipment_item si,
                shipment_item_status sis,
                variant v,
                size s,
                size s2,
                product p,
                designer d,
                product_attribute pa,
                size_scheme ss,
                colour c,
                classification pc
         WHERE  si.shipment_item_status_id  = sis.id
           AND  si.variant_id               = v.id
           AND  v.size_id                   = s.id
           AND  v.designer_size_id          = s2.id
           AND  v.product_id                = p.id
           AND  p.designer_id               = d.id
           AND  v.product_id                = pa.product_id
           AND  pa.size_scheme_id           = ss.id
           AND  p.colour_id                 = c.id
           AND  p.classification_id         = pc.id
    ;

    -- make sure 'www' can read the views!
    GRANT SELECT ON invoice_item_information  TO www;
    GRANT SELECT ON shipment_item_information TO www;

    -- we've had to add a field to the orders table to store whether
    -- we're using an external service (vertex) for tax/shipping
    ALTER TABLE orders
        ADD COLUMN  use_external_tax_rate   boolean default False
    ;
COMMIT;
