-- PWS has:
--   +-------------------+-------------+------+-----+---------+----------------+
--   | Field             | Type        | Null | Key | Default | Extra          |
--   +-------------------+-------------+------+-----+---------+----------------+
--   | usage_count       | int(11)     | NO   |     | 0       |                |
--
-- making the backed match, because it's too much hassle arsing about with the
-- PWS schema
BEGIN WORK;
    -- fix existing
    UPDATE promotion.coupon
    SET usage_count=0
    WHERE usage_count IS NULL;

    -- fix future
    ALTER TABLE promotion.coupon
    ALTER COLUMN usage_count
    SET DEFAULT 0;
COMMIT;
