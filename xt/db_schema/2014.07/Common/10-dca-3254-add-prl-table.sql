BEGIN TRANSACTION;

CREATE TABLE prl_speed (
  id                         INTEGER  NOT NULL PRIMARY KEY,
  name                       TEXT     NOT NULL,
  display_name               TEXT     NOT NULL
);
ALTER TABLE prl_speed OWNER to www;

COMMENT ON TABLE prl_speed IS
'Broadly the time it takes to pick something from the PRL
This influences pick order when a shipment has items in many PRLs';

INSERT INTO prl_speed (id, name, display_name) VALUES
(1, 'slow', 'Slow'),
(2, 'fast', 'Fast');

CREATE TABLE prl_pick_trigger_method (
  id                         INTEGER  NOT NULL PRIMARY KEY,
  name                       TEXT     NOT NULL,
  display_name               TEXT     NOT NULL
);
ALTER TABLE prl_pick_trigger_method OWNER to www;

COMMENT ON TABLE prl_pick_trigger_method IS
'When the first PRL triggers a pick in a second PRL, this is done by
* induction - When the first PRL''s containers are inducted
* pick_complete - When we receive the pick_complete for the first PRL''s allocation';

INSERT INTO prl_pick_trigger_method (id, name, display_name) VALUES
(1,'induction','Induction'),
(2,'pick_complete','Pick Complete');

CREATE TABLE prl_pack_space_allocation_time (
  id                         INTEGER  NOT NULL PRIMARY KEY,
  name                       TEXT     NOT NULL,
  display_name               TEXT     NOT NULL
);
ALTER TABLE prl_pack_space_allocation_time OWNER to www;

COMMENT ON TABLE prl_pack_space_allocation_time IS
'Information about the times at which PRLs allocate stock
* induction - No pack space is allocated until the Containers are manually inducted
  i.e. pack space is allocated when the Containers are inducted
* pick - Pack space is allocated when the pick message is sent
  i.e. the pick isn''t sent until pack space is allocated
* pick_complete - Pack space is allocated when the pick_complete message is received
  i.e. pack space is allocated before the Containers become ready to be inducted';

INSERT INTO prl_pack_space_allocation_time (id, name, display_name) VALUES
(1,'induction','Induction'),
(2,'pick','Pick'),
(3,'pick_complete','Pick Complete');

CREATE TABLE prl_pack_space_unit (
  id                         INTEGER  NOT NULL PRIMARY KEY,
  name                       TEXT     NOT NULL,
  display_name               TEXT     NOT NULL
);
ALTER TABLE prl_pack_space_unit OWNER to www;

COMMENT ON TABLE prl_pack_space_unit IS
'There is a Packing capacity, which picks can allocate.
For PRLs where pack space is allocated after picking, the number of containers is used
This counts higher for multi-tote allocations, but is balanced by single-item picks in the same tote.
For PRLs where pack space is allocated before anything is put in the final tote the number of allocations is used
This counts lower for multi-tote allocations, but is balanced by single-item picks in the same tote.';

INSERT INTO prl_pack_space_unit (id, name, display_name) VALUES
(1,'container','Container'),
(2,'allocation','Allocation');

CREATE TABLE prl (
  id                                INTEGER  NOT NULL PRIMARY KEY,
  name                              TEXT     NOT NULL,
  display_name                      TEXT     NOT NULL,
  is_active                         BOOLEAN  NOT NULL,
  location_id                       INTEGER REFERENCES location(id),
  prl_speed_id                      INTEGER NOT NULL REFERENCES prl_speed(id),
  prl_pick_trigger_method_id        INTEGER REFERENCES prl_pick_trigger_method(id),
  prl_pack_space_allocation_time_id INTEGER NOT NULL REFERENCES prl_pack_space_allocation_time(id),
  prl_pack_space_unit_id            INTEGER NOT NULL REFERENCES prl_pack_space_unit(id),
  has_staging_area                  BOOLEAN  NOT NULL,
  has_container_transfer            BOOLEAN  NOT NULL,
  has_induction_point               BOOLEAN  NOT NULL,
  has_local_collection_point        BOOLEAN  NOT NULL,
  has_conveyor_to_packing           BOOLEAN  NOT NULL,
  amq_queue                         TEXT,
  amq_identifier                    TEXT,
  CONSTRAINT active_prl_has_location
    CHECK (NOT (is_active AND location_id IS NULL))
);
ALTER TABLE prl OWNER to www;

COMMENT ON TABLE prl IS 'Information about PRLs';
COMMENT ON COLUMN prl.name IS 'Name of the PRL';
COMMENT ON COLUMN prl.display_name IS 'Displayed name of the PRL';
COMMENT ON COLUMN prl.is_active IS 'Whether the PRL is currently active';
COMMENT ON COLUMN prl.location_id IS
'The id of the location that XT uses for this PRL';
COMMENT ON COLUMN prl.has_staging_area IS
'This is for PRLs where the pack space is allocated at Induction, not before.
Kinda part of the Induction Point.
Place where Containers end up after pick_complete, but before they can be sent/taken to packing.
While in the staging area, they still don''t have allocated pack space.
At the Induction point: Nothing can be inducted unless it has booked packing capacity.
Packing Exception: Things can always be inducted from.';
COMMENT ON COLUMN prl.has_induction_point IS
'Induction means to logically move the Containers to Packing.
Logically, because e.g. in the case of Cage (which Has Local Collection Point)
it might stay in the cage, waiting for someone to fetch it.
For Full WH, physically known as "wall of totes".
Containers can be moved to packing by walking (sending, or fetching) or Conveyor.
Packing Exception can function as an Induction Point (using the same screen as regular Induction).
The Induction Point has a screen with Picked and Staged Allocations and Containers that need to go to Packing.
If the PRL "Has Conveyor to Packing", Containers can sometimes be conveyed to packing, but not for overly full Containers.
(current implementation only) Not for Containers in the "Full PRL cage room".
This is the latest stage where a specific pack lane is assigned if there isn''t already one (in a multi-prl, multi-tote scenario)';
COMMENT ON COLUMN prl.has_local_collection_point IS
'After induction, the Containers aren''t immediately brought to packing
e.g. they are too valuable to have laying around at packing.
Cannot be immediately brought to packing.
Instead they are put aside near the PRL area, and has to be brought to pack lane,
if no other containers are at pack lane to be scanned fetched from the collection point,
if other containers are at pack lane being scanned.';
COMMENT ON COLUMN prl.has_conveyor_to_packing IS
'Just because there is a conveyor to packing doesn''t mean all Containers can be conveyed
e.g. if it''s too heavy or contains too large items';

CREATE TABLE prl_pick_trigger_order (
  id                         INTEGER NOT NULL PRIMARY KEY,
  triggers_picks_in_id       INTEGER NOT NULL REFERENCES prl(id),
  picks_triggered_by_id      INTEGER NOT NULL REFERENCES prl(id),
  trigger_order              INTEGER NOT NULL
);
ALTER TABLE prl_pick_trigger_order OWNER to www;

COMMENT ON TABLE prl_pick_trigger_order IS
'In a multi-PRL Shipment, the second PRL''s pick is triggered by pick_complete in the first PRL.
Picks in the second PRL are triggered by a pick_complete from the PRL with the lowest trigger_order value.
Picks in all PRLs can also be triggered by auto-selection.
If there are many slow PRLs involved, they are all triggered by selection at the same time';
COMMENT ON COLUMN prl_pick_trigger_order.picks_triggered_by_id IS
'Id of the PRL that can trigger a pick in another PRL';
COMMENT ON COLUMN prl_pick_trigger_order.triggers_picks_in_id IS
'Id of the PRL that can have picks triggered by another PRL';
COMMENT ON COLUMN prl_pick_trigger_order.trigger_order IS
'Order that PRLs can trigger picks in another PRL';

CREATE TABLE prl_integration (
  id                         INTEGER NOT NULL PRIMARY KEY,
  source_prl_id              INTEGER NOT NULL REFERENCES prl(id),
  target_prl_id              INTEGER NOT NULL REFERENCES prl(id)
);
ALTER TABLE prl_integration OWNER to www;

COMMENT ON TABLE prl_integration IS
'Integration is the ability to pick items from two PRLs into the same tote.
After container_ready in the first PRL, it might be sent to one other PRL for integration.
The purpose is to minimise use of totes, and use of the multi-tote pack lanes
This is only feasible if the shipment is small enough to fit in one tote.
If it''s not feasible, the tote is simply not integrated and is sent separately to a multi-tote pack pane.';
COMMENT ON COLUMN prl_integration.source_prl_id IS
'Id of the PRL that a tote can come from.';
COMMENT ON COLUMN prl_integration.target_prl_id IS
'Id of the PRL that a tote can be sent to.';

COMMIT;
