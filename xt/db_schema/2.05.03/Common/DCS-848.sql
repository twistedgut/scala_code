-- DCS-841
--
-- Differentiate between "Classic Promotions" and "Promotional Events"
--
-- the easiest way seems to be to just add a column to flag classic tinkers
--
-- remember that the export_to_pws() will fail if the column isn't also added
-- to their database(s)
--
--      ALTER TABLE event_detail ADD COLUMN is_classic tinyint(1) NULL;
--

BEGIN;
    -- add the new column; everything defaults no "not classic, it's new"
    ALTER TABLE event.detail
        ADD COLUMN is_classic boolean default false NOT NULL;


    -- anything that's "Promotion" and "not product page visible" should be flagged as "classic"
    UPDATE event.detail
       SET is_classic = true
     WHERE event_type_id = (
            SELECT id FROM event.type WHERE name='Promotion'
           )
       AND product_page_visible = false
    ;

    -- make sure that anything that's not a promotion is NOT product_page_visible
    UPDATE event.detail
       SET product_page_visible = false
     WHERE event_type_id = (
            SELECT id FROM event.type WHERE name='Promotion'
           )
       AND product_page_visible = true
    ;
COMMIT;
