BEGIN;


-- Populate Exclusion Calendar for OUT
INSERT INTO csm_exclusion_calendar (csm_id,start_time,end_time,start_date)
SELECT  csm.id,
        CAST('21:00:00' AS TIME),
        CAST('07:59:59' AS TIME),
        null
FROM    correspondence_subject_method csm
        JOIN correspondence_subject cs ON cs.id = csm.correspondence_subject_id AND subject = 'Premier Delivery' AND cs.channel_id = (
            SELECT id FROM channel WHERE web_name ilike 'OUTNET-%'
        )
        JOIN correspondence_method cm ON cm.id = csm.correspondence_method_id AND method = 'SMS'
UNION
SELECT  csm.id,
        null,
        null,
        '25/12'
FROM    correspondence_subject_method csm
        JOIN correspondence_subject cs ON cs.id = csm.correspondence_subject_id AND subject = 'Premier Delivery' AND cs.channel_id = (
            SELECT id FROM channel WHERE web_name ilike 'OUTNET-%'
        )
        JOIN correspondence_method cm ON cm.id = csm.correspondence_method_id AND method = 'SMS'
ORDER BY 1,2
;



COMMIT;
