
BEGIN;

-- The GOH PRL does in fact not have an induction point. It has an
-- integration point, but it doesn't have a list of things to induct
-- and no induction capacity; hence, no induction point

update prl
    set has_induction_point = false
    where name = 'GOH';

COMMIT;
