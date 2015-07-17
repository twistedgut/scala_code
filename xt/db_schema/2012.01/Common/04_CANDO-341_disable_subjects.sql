-- CANDO-431: Disable Subjects - Make all of the Subjects disabled until
--            ready to go live with all of the Premier Delivery functionality

BEGIN WORK;

UPDATE  correspondence_subject
    SET enabled = FALSE
;

COMMIT WORK;
