-- Decline expired sample review requests

BEGIN;

CREATE OR REPLACE FUNCTION decline_sample_requests(
    before_date timestamp
) RETURNS VOID AS $$
DECLARE
    declined_id INT;
    awaiting_approval_id INT;
    sample_record RECORD;
    sample_request_total INT;
    sample_request_count INT := 0;
BEGIN
    -- Store some useful statuses
    SELECT id INTO declined_id FROM sample_request_det_status WHERE status = 'Declined';
    SELECT id INTO awaiting_approval_id FROM sample_request_det_status WHERE status = 'Awaiting Approval';

    -- Determine the total number of rows to update
    SELECT count(*) INTO sample_request_total FROM sample_request_det me
        JOIN sample_request sr ON me.sample_request_id = sr.id
        WHERE me.sample_request_det_status_id = awaiting_approval_id
        AND sr.date_requested < before_date;

    -- Loop through the sample requests we want to update
    FOR sample_record IN
        SELECT me.id, sr.id sr_id FROM sample_request_det me
            JOIN sample_request sr ON me.sample_request_id = sr.id
            WHERE me.sample_request_det_status_id = awaiting_approval_id
            AND sr.date_requested < before_date
            ORDER BY me.id
    LOOP
        sample_request_count := sample_request_count + 1;
        RAISE NOTICE 'Declining id % of sample request % (%/%)',
            sample_record.id, sample_record.sr_id, sample_request_count, sample_request_total;

        -- Set the sample request as declined
        UPDATE sample_request_det
            SET sample_request_det_status_id = declined_id
            WHERE id = sample_record.id;
        -- Do nothing if the sample request still has incomplete items
        CONTINUE WHEN EXISTS(
            SELECT 1
            FROM sample_request_det me
            JOIN sample_request_det_status srds ON me.sample_request_det_status_id = srds.id
            WHERE me.sample_request_id = sample_record.sr_id
            AND srds.status IN ('Awaiting Approval', 'Approved', 'Transferred')
            LIMIT 1
        );
        -- Complete the request
        UPDATE sample_request
            SET date_completed = now()
            WHERE id = sample_record.sr_id;
        RAISE NOTICE 'Sample request % completed', sample_record.sr_id;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Decline any samples requested before 2014-04-01
SELECT decline_sample_requests('2014-04-01');
DROP FUNCTION decline_sample_requests(timestamp);
COMMIT;
