-- CANDO-2885: Change the 'returnable' flag on the Shipment Item
--             table to point to a reference lookup table

BEGIN WORK;

--
-- Create new Look-up Table
--

CREATE TABLE shipment_item_returnable_state (
    id                  SERIAL PRIMARY KEY,
    state               CHARACTER VARYING(255) NOT NULL UNIQUE,
    pws_key             CHARACTER VARYING(255) NOT NULL UNIQUE,
    returnable_on_pws   BOOLEAN NOT NULL
);

ALTER TABLE shipment_item_returnable_state OWNER TO postgres;
GRANT ALL ON TABLE shipment_item_returnable_state TO www;
GRANT ALL ON SEQUENCE shipment_item_returnable_state_id_seq TO www;

-- Populate the Table, explictely set the Id's so they are known
-- exactly when it comes to changing the 'shipment_item' table
INSERT INTO shipment_item_returnable_state (id,state,pws_key,returnable_on_pws) VALUES
(1,'Yes','YES',TRUE),
(2,'No','NO',FALSE),
(3,'CC Only','CC_ONLY',FALSE)
;

-- Now Reset the Next Id so it's correct for future Inserts
SELECT  SETVAL(
    'shipment_item_returnable_state_id_seq',
    ( SELECT MAX(id) FROM shipment_item_returnable_state )
)
;

--
-- Add a new column 'returnable_state_id' for the new way of
-- doing things, default to 1 (Yes) so then only need to
-- update the 'No' which there will be a lot fewer of
--
ALTER TABLE shipment_item
    ADD COLUMN returnable_state_id INTEGER NOT NULL REFERENCES shipment_item_returnable_state(id) DEFAULT 1
;

--
-- Create a Temp table to store all the current NON Returnable
-- Ids so they can be updated with the correct state
--
CREATE TEMP TABLE tmp_not_returnable ( item_id INTEGER );
INSERT INTO tmp_not_returnable (item_id)
SELECT  id
FROM    shipment_item
WHERE   returnable = FALSE
;

--
-- Now update all Non-Returnable Items to the new State
--
UPDATE shipment_item
    SET returnable_state_id = 2     -- No
WHERE id IN (
    SELECT  item_id
    FROM    tmp_not_returnable
)
;

--
-- Remove the old Column and remove the Default from the new one
--
ALTER TABLE shipment_item
    DROP COLUMN returnable,
    ALTER COLUMN returnable_state_id DROP DEFAULT
;

COMMIT WORK;
