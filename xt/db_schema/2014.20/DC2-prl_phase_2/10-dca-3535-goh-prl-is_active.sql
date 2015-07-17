
--
-- Activate the GOH PRL. This only happens in PRL rollout phase 2, and
-- will probably be set as a BAU when we launch in Live.
--
-- Currently, this is controlled by the nap.properties
-- prl_rollout_phase, which will initially be set to 2 in various DC2
-- environments and Jenkins jobs.
--

BEGIN;

update prl
    set is_active = true
    where name = 'GOH';

COMMIT;
