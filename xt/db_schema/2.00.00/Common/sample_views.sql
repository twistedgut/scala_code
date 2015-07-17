BEGIN;

DROP VIEW vw_sample_request_header;

CREATE VIEW vw_sample_request_header AS
	SELECT	srq.id AS sample_request_id, lpad(srq.id::text, 5, 0::text) AS sample_request_ref, to_char(srq.date_requested, 'DD-Mon-YYYY HH24:MI'::text) AS date_requested, srq.date_requested AS date_requested_date, COALESCE(oic.overdue_item_count, 0::bigint) AS overdue_item_count, to_char(srq.date_completed, 'DD-Mon-YYYY HH24:MI'::text) AS date_completed, srq.notes, srt.id AS type_id, srt.type, srq.requester_id, op.name AS requester_name, srr.sample_receiver_id, src.name AS receiver_name, oa.address_line_1, oa.address_line_2, oa.address_line_3, oa.towncity, oa.county, oa.country, oa.postcode,
			ch.id AS channel_id, ch.name AS sales_channel
	FROM	sample_request srq
				JOIN channel ch ON ch.id = srq.channel_id
				JOIN sample_request_type srt ON srq.sample_request_type_id = srt.id
				JOIN operator op ON srq.requester_id = op.id
					LEFT JOIN (sample_request_receiver srr
								JOIN (sample_receiver src
								JOIN order_address oa ON src.address_id = oa.id) ON srr.sample_receiver_id = src.id) ON srq.id = srr.sample_request_id
						LEFT JOIN ( SELECT	sample_request_det.sample_request_id, COUNT(*) AS overdue_item_count
									FROM	sample_request_det
									wHERE	sample_request_det.date_returned IS NULL
									AND sample_request_det.date_return_due <= 'now'::text::timestamp without time zone
									GROUP BY sample_request_det.sample_request_id) oic ON srq.id = oic.sample_request_id
;

GRANT ALL ON vw_sample_request_header TO www;

COMMIT;

BEGIN;

-- Remove 'Manage Requests' from users menu
DELETE FROM operator_authorisation
WHERE authorisation_sub_section_id = (
		SELECT	id
		FROM	authorisation_sub_section
		WHERE	sub_section = 'Manage Requests'
	)
;

-- Remove 'Manage Requests' from the system
DELETE FROM authorisation_sub_section
WHERE sub_section = 'Manage Requests'
;

COMMIT;

BEGIN;

-- Change 'SampleUsers' to 'SampleCartUsers'
UPDATE authorisation_sub_section
	SET sub_section = 'Sample Cart Users'
WHERE sub_section = 'Sample Users'
;

COMMIT;
