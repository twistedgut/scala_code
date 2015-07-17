BEGIN;

delete from pack_lane_has_attribute where pack_lane_id = (select pack_lane_id from pack_lane where human_name='packing_no_read');
delete from pack_lane_has_attribute where
        pack_lane_id = (select pack_lane_id from pack_lane where human_name='seasonal_line')
    and pack_lane_attribute_id = (select pack_lane_attribute_id from pack_lane_attribute where name='STANDARD');
insert into pack_lane_has_attribute (pack_lane_id, pack_lane_attribute_id) select pack_lane_id, pack_lane_attribute_id from pack_lane pl, pack_lane_attribute pla where pl.human_name='seasonal_line' and pla.name='DEFAULT';

COMMIT;
