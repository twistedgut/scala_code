-- Create missing designer category nav data for MrP designers 
-- that don't already have it

BEGIN;

CREATE FUNCTION create_designer_nav (
    designer_att_id INTEGER
)
RETURNS INTEGER AS $$
DECLARE
    new_nt_id INTEGER;
BEGIN
    INSERT INTO product.navigation_tree (attribute_id, parent_id, sort_order, visible, deleted)
        VALUES (designer_att_id, null, 1, true, false)
        RETURNING id INTO new_nt_id;
    UPDATE product.navigation_tree
        SET parent_id = id
        WHERE id = new_nt_id AND parent_id is null;
    RETURN new_nt_id;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION create_designer_cat_nav (
    new_nt_id INTEGER,
    att_id INTEGER
)
RETURNS INTEGER AS $$
DECLARE
    new_nt_cat_id INTEGER;
BEGIN
    INSERT INTO product.navigation_tree (attribute_id, parent_id, sort_order, visible, deleted)
        VALUES (att_id, new_nt_id, 1, true, false)
        RETURNING id INTO new_nt_cat_id;
    RETURN new_nt_cat_id;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION insert_mrp_designer_cats ()
RETURNS VOID AS $$
DECLARE
    mrp_channel_id INTEGER;
    designer_att_id INTEGER;
    new_nt_id INTEGER;
    existing_id INTEGER;
    mrp_att_id INTEGER;
    cat_name VARCHAR;
BEGIN
    SELECT id FROM public.channel WHERE name = 'MRPORTER.COM' into mrp_channel_id;
    FOR designer_att_id IN
        SELECT id
            FROM product.attribute
            WHERE channel_id=mrp_channel_id AND attribute_type_id=9
    LOOP
        SELECT ea.id
            FROM product.attribute ea, product.navigation_tree ent
            WHERE ea.id=ent.attribute_id
            AND ea.channel_id=mrp_channel_id
            AND ea.attribute_type_id=9
            AND ea.id=designer_att_id
            INTO existing_id;
        IF existing_id IS NULL THEN
            -- add designer nav
            new_nt_id = create_designer_nav(designer_att_id);
            -- now do for each nav level 1
            FOR cat_name IN 
                SELECT name FROM product.attribute
                    WHERE attribute_type_id=1 AND channel_id=mrp_channel_id
                    AND name!='Unknown'
            LOOP
                SELECT id FROM product.attribute
                    WHERE channel_id=mrp_channel_id AND name=cat_name AND attribute_type_id=1
                    INTO mrp_att_id;
                PERFORM create_designer_cat_nav(new_nt_id, mrp_att_id);
            END LOOP;
        END IF;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;


SELECT insert_mrp_designer_cats();

DROP FUNCTION insert_mrp_designer_cats();
DROP FUNCTION create_designer_nav(INTEGER);
DROP FUNCTION create_designer_cat_nav(INTEGER, INTEGER);

COMMIT;
