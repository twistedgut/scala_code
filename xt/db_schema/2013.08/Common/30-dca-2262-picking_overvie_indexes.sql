
-- DCA-2272: Picking Overview - add indexes

BEGIN;

CREATE INDEX ON allocation_item (status_id);
CREATE INDEX ON stock_transfer (channel_id);
CREATE INDEX ON allocation_item (allocation_id);
CREATE INDEX ON allocation_item (picked_at);
CREATE INDEX ON allocation (status_id);
CREATE INDEX ON allocation (pick_sent);

COMMIT;
