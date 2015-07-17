-- CANDO-3378: Add new Role for sending the
--             Order Status Message

BEGIN WORK;

INSERT INTO acl.authorisation_role (authorisation_role) VALUES
('app_canSendOrderStatusMessage')
;

COMMIT WORK;
