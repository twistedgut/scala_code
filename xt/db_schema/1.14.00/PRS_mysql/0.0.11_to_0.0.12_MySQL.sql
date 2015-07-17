START TRANSACTION;
    ALTER TABLE detail
        ADD order_line_heading varchar(30)
    ;

    ALTER TABLE detail
        ADD order_line_text varchar(75)
    ;

    ALTER TABLE detail
        ADD created timestamp
    ;


    ALTER TABLE detail
        ADD created_by integer
    ;
    UPDATE detail SET created_by=0
    ;
    ALTER TABLE detail
        MODIFY COLUMN created_by integer NOT NULL
    ;



    ALTER TABLE detail
        ADD last_modified timestamp
    ;

    ALTER TABLE detail
        ADD last_modified_by integer
    ;
    UPDATE detail SET last_modified_by=0
    ;


    -- add missing link from coupon to promotion
    ALTER TABLE coupon
        ADD COLUMN promotion_detail_id integer NOT NULL
            references detail(id)
    ;

COMMIT;
