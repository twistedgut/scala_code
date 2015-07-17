BEGIN TRANSACTION;

INSERT INTO prl
(
  id, name, display_name,is_active, location_id, prl_speed_id,
  prl_pick_trigger_method_id, prl_pack_space_allocation_time_id,
  prl_pack_space_unit_id,
  has_staging_area, has_container_transfer, has_induction_point,
  has_local_collection_point, has_conveyor_to_packing,
  amq_queue, amq_identifier
)
VALUES
(
  1,'Full','Full Warehouse',FALSE,NULL,1,1,1,1,
  TRUE,FALSE,TRUE,FALSE,TRUE,
  '/queue/dc2/prl_full','Full'
),
(
  2,'Dematic','DCD',FALSE,NULL,2,NULL,2,2,
  FALSE,FALSE,FALSE,FALSE,TRUE,
  '/queue/dc2/prl_dematic','dcd'
),
(
  3,'GOH','GOH',FALSE,NULL,1,2,3,2,
  FALSE,TRUE,TRUE,FALSE,TRUE,
  '/queue/dc2/prl_goh','GOH'
),
(
  4,'Cage','Cage',FALSE,NULL,1,1,1,1,
  TRUE,FALSE,TRUE,TRUE,FALSE,
  NULL,NULL
),
(
  5,'Oversize','Oversize',FALSE,NULL,1,1,1,1,
  TRUE,FALSE,TRUE,FALSE,FALSE,
  NULL,NULL
);

UPDATE prl
SET    location_id = (SELECT id FROM location WHERE location = 'Full PRL')
WHERE  id = 1;

UPDATE prl
SET    location_id = (SELECT id FROM location WHERE location = 'Dematic PRL')
WHERE  id = 2;

UPDATE prl
SET    is_active = TRUE
--WHERE  id = 1;
WHERE  id IN (1, 2);

INSERT INTO prl_pick_trigger_order
(id, triggers_picks_in_id, picks_triggered_by_id, trigger_order)
VALUES
(1, 2, 3, 1),  -- GOH triggers picks in DCD
(2, 2, 1, 2),  -- Full triggers picks in DCD
(3, 2, 4, 3),  -- Cage triggers picks in DCD
(4, 2, 5, 4);  -- Oversize triggers picks in DCD

INSERT INTO prl_integration
(id, source_prl_id, target_prl_id)
VALUES
(1,2,3);       -- DCD integrates with GOH

COMMIT;
