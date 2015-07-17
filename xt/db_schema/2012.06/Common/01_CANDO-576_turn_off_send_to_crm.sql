-- CANDO-576: Turn's Off sending an Email to eGain (our CRM)
--            when a SMS is sent to the SMS Proxy

BEGIN WORK;

UPDATE  correspondence_subject_method
    SET copy_to_crm = FALSE
WHERE   copy_to_crm = TRUE
;

COMMIT WORK;
