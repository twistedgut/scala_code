--
-- CANDO-8351: Add new renumeration reason for 'HAZMAT Non-returnable Item'
--

BEGIN WORK;

INSERT INTO renumeration_reason ( renumeration_reason_type_id, reason )
VALUES (
  ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ),
  'HAZMAT Non-returnable Item'
);

COMMIT WORK;
