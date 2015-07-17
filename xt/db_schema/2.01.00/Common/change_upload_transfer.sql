-- Change the 'upload.transfer' table to store
-- the Upload Id from Fulcrum.
-- Also change the view 'vw_transfers'

BEGIN WORK;

ALTER TABLE upload.transfer ADD COLUMN upload_id INTEGER;

COMMIT WORK;

BEGIN WORK;

DROP VIEW upload.vw_transfers;

-- re-create view
CREATE VIEW upload.vw_transfers AS
	SELECT	t.id,
			t.upload_date,
			t.channel_id,
			business.config_section as channel_config,
			t.operator_id,
			t.source,
			t.sink,
			t.environment,
			t.transfer_status_id,
			t.dtm,
			to_char(t.dtm, 'DD-Mon-YYYY HH24:MI:SS'::text) AS txt_dtm,
			tstat.status,
			to_char((t.upload_date)::timestamp with time zone, 'DD-Mon-YYYY HH24:MI:SS'::text) AS txt_upload_date,
			op.name AS operator_name,
			(
				SELECT	COUNT(pc.product_id) AS count
				FROM	public.product_channel pc
				WHERE	(pc.upload_date = t.upload_date
				AND		pc.channel_id = t.channel_id)
			) AS num_upload_products,
			(
				SELECT	COUNT(DISTINCT tl.product_id) AS count
				FROM	upload.transfer_log tl
				WHERE	(tl.transfer_id = t.id)
			) AS num_products_logged,
			t.upload_id
	FROM	(((upload.transfer t
				JOIN upload.transfer_status tstat ON ((t.transfer_status_id = tstat.id))))
				JOIN public."operator" op ON ((t.operator_id = op.id))
				JOIN public.channel ch ON ((t.channel_id = ch.id))
				JOIN business ON ((ch.business_id = business.id)) );

ALTER TABLE upload.vw_transfers OWNER TO postgres;
REVOKE ALL ON TABLE upload.vw_transfers FROM PUBLIC;
REVOKE ALL ON TABLE upload.vw_transfers FROM postgres;
GRANT ALL ON TABLE upload.vw_transfers TO postgres;
GRANT SELECT ON TABLE upload.vw_transfers TO www;

COMMIT WORK;
