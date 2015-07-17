-- we need/want to rename the underlying schema to match the central system
-- rather than take part in a copy-paste exercise, it seems prudent to just
-- use the files we used in xt-central to move from the promotion -> event
-- schema

-- the contents of the script are already inside BEGIN ... COMMIT
\i /opt/xt_central/db_schema/006_promotion2event.sql
\i /opt/xt_central/db_schema/008_event_public_sale.sql
