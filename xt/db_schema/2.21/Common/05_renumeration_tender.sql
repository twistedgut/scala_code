BEGIN;

	CREATE TABLE renumeration_tender (
		renumeration_id integer references renumeration(id) DEFERRABLE NOT NULL,
		tender_id integer references orders.tender(id) DEFERRABLE NOT NULL,
		value numeric (10,3) NOT NULL,
		PRIMARY KEY (renumeration_id, tender_id)
	);

	ALTER TABLE renumeration_tender OWNER TO www;

COMMIT;
