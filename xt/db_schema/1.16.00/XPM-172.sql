-- Coupon maximum usages - quantity pre-set on drop down menu

BEGIN;

    -- use whatever the sequence gives us ..
    SELECT SETVAL (
        'promotion.coupon_restriction_id_seq', 
        (select max(id) from promotion.coupon_restriction)
    );

    \set grpsql '(select id from promotion.coupon_restriction_group where name=\'Item Limit\')'
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES
    (default,   'limited to 10 items',      :grpsql,    51,   10),
    (default,   'limited to 25 items',      :grpsql,    52,   25),
    (default,   'limited to 50 items',      :grpsql,    53,   50),
    (default,   'limited to 100 items',     :grpsql,    54,  100),
    (default,   'limited to 500 items',     :grpsql,    55,  500),
    (default,   'limited to 1000 items',    :grpsql,    56, 1000)
    ;

    \set grpsql '(select id from promotion.coupon_restriction_group where name=\'Order Limit\')'
    INSERT INTO promotion.coupon_restriction (id, description, group_id, idx, usage_limit)
    VALUES
    (default,   'limited to 10 orders',     :grpsql,    111,   10),
    (default,   'limited to 25 orders',     :grpsql,    112,   25),
    (default,   'limited to 50 orders',     :grpsql,    113,   50),
    (default,   'limited to 100 orders',    :grpsql,    114,  100),
    (default,   'limited to 500 orders',    :grpsql,    115,  500),
    (default,   'limited to 1000 orders',   :grpsql,    116, 1000)
    ;

COMMIT;
