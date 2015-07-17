
BEGIN;

-- Remove container to packlane links.
update
    container
set
    pack_lane_id = null,
    has_arrived = null,
    arrived_at = null,
    routed_at = null
where
    pack_lane_id is not null;

-- Delete EVERYTHING pack lane related.
delete from pack_lane_has_attribute;
delete from pack_lane_attribute;
delete from pack_lane;

------------------------------------------------
-- Now reinsert the default data.
-- Everything is EXPLICITLY hardcoded on purpose
------------------------------------------------
insert into pack_lane_attribute (pack_lane_attribute_id, name) values
    (1, 'STANDARD'),
    (2, 'PREMIER'),
    (3, 'SAMPLE'),
    (4, 'DEFAULT'),
    (5, 'SINGLE'),
    (6, 'MULTITOTE');

insert into pack_lane (
    pack_lane_id,
    human_name,
    internal_name,
    capacity,
    active,
    container_count,
    is_editable
) values
    (1  , 'pack_lane_1'            , 'DA.PO01.0000.CCTA01NP02' , 14, true, 0, true), -- the only enabled standard single pack lane
    (2  , 'multi_tote_pack_lane_1' , 'DA.PO01.0000.CCTA01NP03' , 7 , true, 0, true), -- the only enabled standard multitote pack lane
    (3  , 'packing_no_read'        , 'DA.PO01.0000.CCTA01NP04' , 7 , false, 0, false),
    (4  , 'multi_tote_pack_lane_2' , 'DA.PO01.0000.CCTA01NP05' , 7 , true, 0, true),  -- the only enabled premier single pack lane
    (5  , 'pack_lane_2'            , 'DA.PO01.0000.CCTA01NP06' , 23, true, 0, true),  -- the only enabled premier multitote pack lane
    (6  , 'multi_tote_pack_lane_3' , 'DA.PO01.0000.CCTA01NP07' , 7 , false, 0, true),
    (7  , 'multi_tote_pack_lane_4' , 'DA.PO01.0000.CCTA01NP08' , 7 , false, 0, true),
    (8  , 'pack_lane_3'            , 'DA.PO01.0000.CCTA01NP09' , 23, false, 0, true),
    (9  , 'multi_tote_pack_lane_5' , 'DA.PO01.0000.CCTA01NP10' , 7 , false, 0, true),
    (10 , 'multi_tote_pack_lane_6' , 'DA.PO01.0000.CCTA01NP11' , 7 , false, 0, true),
    (11 , 'pack_lane_4'            , 'DA.PO01.0000.CCTA01NP12' , 23, false, 0, true),
    (12 , 'multi_tote_pack_lane_7' , 'DA.PO01.0000.CCTA01NP13' , 7 , false, 0, true),
    (13 , 'multi_tote_pack_lane_8' , 'DA.PO01.0000.CCTA01NP14' , 7 , false, 0, true),
    (14 , 'pack_lane_5'            , 'DA.PO01.0000.CCTA01NP15' , 14, false, 0, true),
    (15 , 'seasonal_line'          , 'DA.PO01.0000.CCTA01NP16' , 12, true, 0, true); -- the sample lane. for single and multitote containers

-- regular packlanes need 'SINGLE' packlane attribute. (this cannot be done through the interface)
insert into pack_lane_has_attribute (pack_lane_id, pack_lane_attribute_id) values
    (1, 5),
    (5, 5),
    (8, 5),
    (11, 5),
    (14, 5),
    (15, 5);

-- denote all multitote lanes as 'MULTITOTE'
insert into pack_lane_has_attribute (pack_lane_id, pack_lane_attribute_id) values
    (2, 6),
    (4, 6),
    (6, 6),
    (7, 6),
    (9, 6),
    (10, 6),
    (12, 6),
    (13, 6),
    (15, 6); -- 15 is SINGLE and MULTITOTE. There is one sample lane for BOTH single and multitote shipments.

-- pack_lane_1 and multitote_pack_lane_1 are for premier
insert into pack_lane_has_attribute (pack_lane_id, pack_lane_attribute_id) values
    (1, 2),
    (2, 2);

-- pack_lane_2 and multitote_pack_lane_2 are for standard
insert into pack_lane_has_attribute (pack_lane_id, pack_lane_attribute_id) values
    (4, 1),
    (5, 1);

-- the rest also default to standard ticked as well, even though they aren't enabled.
insert into pack_lane_has_attribute (pack_lane_id, pack_lane_attribute_id) values
    (6, 1),
    (7, 1),
    (8, 1),
    (9, 1),
    (10, 1),
    (11, 1),
    (12, 1),
    (13, 1),
    (14, 1);

-- denote the seasonal_line as the samples lane.
insert into pack_lane_has_attribute (pack_lane_id, pack_lane_attribute_id) values
    (15, 3);

-- errors also go the sample lane
insert into pack_lane_has_attribute (pack_lane_id, pack_lane_attribute_id) values
    (15, 4);

COMMIT;

