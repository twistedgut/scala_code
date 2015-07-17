BEGIN;

-- Add three new columns to the box table:

ALTER TABLE box ADD COLUMN is_conveyable boolean not null default true,
                ADD COLUMN requires_tote boolean not null default false,
                ADD COLUMN sort_order integer not null default 0;

COMMENT ON COLUMN box.is_conveyable IS
'the box can travel on the conveyor belt.';

COMMENT ON COLUMN box.requires_tote IS
'the box is required to travel in a tote.';

COMMENT ON COLUMN box.sort_order IS
'the order in which boxes are displayed on XTracker.';

COMMENT ON COLUMN box.volumetric_weight IS
'Volumetric weight is updated by the volumetric_weight_trigger.';

UPDATE box SET sort_order = id;

ALTER TABLE box ADD UNIQUE(channel_id, sort_order);

COMMIT;
