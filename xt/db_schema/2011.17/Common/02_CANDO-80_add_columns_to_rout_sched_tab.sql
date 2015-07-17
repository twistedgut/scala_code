-- CANDO-80: Add a new column called 'notified' to the 'routing_schedule'
--           table so that it is know if a Schedule or Outcome has been
--           communicated to the Customer or not.

BEGIN WORK;

ALTER TABLE routing_schedule
    ADD COLUMN notified BOOLEAN NOT NULL DEFAULT FALSE
;

COMMIT WORK;
