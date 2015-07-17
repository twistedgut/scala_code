-- http://jira.nap/browse/TP-724

-- "Looking at slower queries it turns out the lookup for new messages is a
-- bit slow."

BEGIN;
    CREATE INDEX operator_message_deleted ON operator.message(deleted);
    CREATE INDEX operator_message_viewed ON operator.message(viewed);
    CREATE INDEX operator_message_recipient_id ON operator.message(recipient_id);
COMMIT;
