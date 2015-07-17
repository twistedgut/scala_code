BEGIN;

    insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
        select 'MRP box',1,2,true,100,100,100,null,id from channel where name = 'MrPorter.com';
   
    select setval('inner_box_id_seq',(select max(id) from inner_box)+1);

    insert into inner_box (inner_box,sort_order,active,outer_box_id,channel_id)
        select 'MRP inner box',(select max(sort_order) from inner_box)+1,true,currval('box_id_seq'),id from channel where name = 'MrPorter.com';

    insert into inner_box (inner_box,sort_order,active,outer_box_id,channel_id)
        select 'MRP no box',(select max(sort_order) from inner_box)+1,true,null,id from channel where name = 'MrPorter.com';

COMMIT;
