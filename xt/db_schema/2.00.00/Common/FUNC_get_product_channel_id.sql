CREATE OR REPLACE FUNCTION get_product_channel_id (p_product_id int) RETURNS int AS $$
	DECLARE l_channel_id	int;

BEGIN
	SELECT	ch.id
	INTO	l_channel_id
	FROM	channel ch,
			product_channel pc
	WHERE	pc.product_id = p_product_id
	AND		ch.id = pc.channel_id
	AND		((pc.live = true and transfer_status_id < 4)
			 OR (live = false and transfer_status_id = 1))
	;

	RETURN l_channel_id;
END;
$$ LANGUAGE plpgsql;
