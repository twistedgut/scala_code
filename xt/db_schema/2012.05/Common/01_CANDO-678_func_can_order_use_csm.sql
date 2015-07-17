-- CANDO-678: Creates a Stored Function to return TRUE or FALSE
--            as to whether an Order can use a Correspondence Method
--            for a Correspondence Subject. This is needed when multiple
--            uses of '$obj->can_use_csm' will slow down a process.

BEGIN WORK;

CREATE OR REPLACE FUNCTION can_order_use_csm(p_order_id INT, p_cust_id INT, p_csm_id INT) RETURNS BOOL AS $$
    DECLARE l_result BOOL;
    DECLARE l_cust_id INT;

    BEGIN
        l_result := FALSE;

        IF p_cust_id = 0
        THEN
            -- if ZERO is in the p_cust_id then this
            -- means search for the Customer Id using
            -- the Order Id
            SELECT  customer_id
            INTO    l_cust_id
            FROM    orders
            WHERE   id = p_order_id
            ;

            IF NOT FOUND
            THEN
                RETURN FALSE;
            END IF;
        ELSE
            l_cust_id = p_cust_id;
        END IF;

        SELECT  CASE
                    -- if anything is Disabled then you CAN'T use the Method
                    WHEN NOT csm.enabled THEN FALSE
                    WHEN NOT cs.enabled THEN FALSE
                    WHEN NOT cm.enabled THEN FALSE
                    -- if you can't opt out then you CAN always use the Method
                    WHEN NOT csm.can_opt_out THEN TRUE
                    -- check Order, Customer, Customer Defaults for the Method
                    WHEN ocp.can_use IS NOT NULL THEN ocp.can_use
                    WHEN ccp.can_use IS NOT NULL THEN ccp.can_use
                    WHEN ccmp.can_use IS NOT NULL THEN ccmp.can_use
                    WHEN c.correspondence_default_preference IS NOT NULL THEN c.correspondence_default_preference
                    -- just use the Default then
                    ELSE csm.default_can_use
                END AS can_use_flag
        INTO    l_result
        FROM    customer c,
                correspondence_subject_method csm
                JOIN correspondence_subject cs
                            ON cs.id = csm.correspondence_subject_id
                JOIN correspondence_method cm
                            ON cm.id = csm.correspondence_method_id
                LEFT JOIN orders_csm_preference ocp
                            ON ocp.csm_id = csm.id AND ocp.orders_id = p_order_id
                LEFT JOIN customer_csm_preference ccp
                            ON ccp.csm_id = csm.id
                            AND ccp.customer_id = l_cust_id
                LEFT JOIN customer_correspondence_method_preference ccmp
                            ON ccmp.customer_id = l_cust_id
                            AND ccmp.correspondence_method_id = csm.correspondence_method_id
        WHERE   c.id = l_cust_id
        AND     csm.id = p_csm_id
        ;

        IF NOT FOUND
        THEN
            l_result := FALSE;
        END IF;

        IF l_result IS NULL
        THEN
            l_result := FALSE;
        END IF;

        RETURN l_result;

    END;
    $$ LANGUAGE plpgsql;

COMMIT WORK;
