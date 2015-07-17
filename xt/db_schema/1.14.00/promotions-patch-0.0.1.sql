-- the first patch after the freezing all the schema work so far (for
-- promotions)

BEGIN WORK;

    -- nail down the join type for each customer group with a(nother) join
    -- table
    CREATE TABLE promotion.detail_customergroupjoin_listtype (
        id                              serial          primary key,
        detail_id                       integer         not null
                                        references promotion.detail(id),
        detail_customergroup_join_id    integer         not null
                                        references promotion.detail_customergroup_join(id),
        customergroup_listtype_id       integer         not null
                                        references
                                        promotion.customergroup_listtype(id),

        UNIQUE(detail_id, detail_customergroup_join_id,customergroup_listtype_id)
    );
    ALTER TABLE promotion.detail_customergroupjoin_listtype OWNER TO www;


    -- this is a terrible thing to do, but we need to be able to store AM
    -- customers in groups in the Intl xt database
    -- Speaking to JT he suggested the terrible thought at the back of my
    -- mind ... remove the FK to the custard table.
    -- Hopefully there's still the FK in each PWS database table
    --
    -- To mitigate this evil, we're adding a new column to state which website
    -- instance we've linked the record to (Intl/AM)
    ALTER TABLE promotion.customer_customergroup
        DROP CONSTRAINT customer_customergroup_customer_id_fkey;
    ALTER TABLE promotion.customer_customergroup
        ADD COLUMN website_id integer NOT NULL references promotion.website(id);

COMMIT;
