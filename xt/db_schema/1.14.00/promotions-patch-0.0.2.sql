-- fix Chisel's eff-up with promotion_detail_id / detail_id mix-up

BEGIN WORK;

    ALTER TABLE promotion.coupon
        RENAME COLUMN promotion_detail_id
        TO detail_id
    ;

COMMIT;
