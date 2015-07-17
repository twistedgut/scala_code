-- WHM-1900: Create and populate pack_lane (and related) tables

BEGIN WORK;


-- Tables and common data were created in 'common' file

-- populate the pack lane table
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(1, 'pack_lane_1', 'DA.PO01.0000.CCTA01NP02', 14, true, 1); -- Single
    INSERT INTO pack_lane_has_attribute VALUES(1, 2); -- Premier
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(2, 'multi_tote_pack_lane_1', 'DA.PO01.0000.CCTA01NP03', 7, true, 2); -- Multi-tote
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(3, 'packing_no_read', 'DA.PO01.0000.CCTA01NP04', 7, true, 3); -- No Read
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(4, 'multi_tote_pack_lane_2', 'DA.PO01.0000.CCTA01NP05', 7, true, 2); -- Multi-tote
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(5, 'pack_lane_2', 'DA.PO01.0000.CCTA01NP06', 23, true, 1); -- Single
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(6, 'multi_tote_pack_lane_3', 'DA.PO01.0000.CCTA01NP07', 7, true, 2);  -- Multi-tote
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(7, 'multi_tote_pack_lane_4', 'DA.PO01.0000.CCTA01NP08', 7, true, 2); -- Multi-tote
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(8, 'pack_lane_3', 'DA.PO01.0000.CCTA01NP09', 23, true, 1); -- Single
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(9, 'multi_tote_pack_lane_5', 'DA.PO01.0000.CCTA01NP10', 7, true, 2); -- Multi-tote
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(10, 'multi_tote_pack_lane_6', 'DA.PO01.0000.CCTA01NP11', 7, true, 2); -- Multi-tote
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(11, 'pack_lane_4', 'DA.PO01.0000.CCTA01NP12', 23, true, 1); -- Single
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(12, 'multi_tote_pack_lane_7', 'DA.PO01.0000.CCTA01NP13', 7, true, 2); -- Multi-tote
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(13, 'multi_tote_pack_lane_8', 'DA.PO01.0000.CCTA01NP14', 7, true, 2); -- Multi-tote
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(14, 'pack_lane_5', 'DA.PO01.0000.CCTA01NP15', 14, true, 1); -- Single
INSERT INTO pack_lane (pack_lane_id, human_name, internal_name, capacity, active, type) VALUES(15, 'seasonal_line', 'DA.PO01.0000.CCTA01NP16', 12, true, 4); -- Seasonal
    INSERT INTO pack_lane_has_attribute VALUES(15, 1); -- Sample

COMMIT WORK;
