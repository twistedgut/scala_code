--
-- CANDO-2288: (CANDO-974, CANDO-1440 & CANDO-2685)
-- Add new reservation source values
--

BEGIN WORK;

INSERT INTO reservation_source (source, sort_order)
VALUES
    ('Limited Availability', 17),
    ('Sale', 18),
    ('Social Media', 19),
    ('PreOrder', 20)
;

COMMIT WORK;
