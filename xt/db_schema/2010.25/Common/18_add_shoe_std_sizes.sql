BEGIN;
    -- Reset sequence
    select setval('std_size_id_seq', (select max(id) from std_size));
    grant all on std_size_mapping_id_seq to www;
    -- Populate standardised value names
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('42.5',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('43',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('43.5',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('44',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('44.5',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('45',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('45.5',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('46',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('46.5',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('47',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('47.5',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('48',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('48.5',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('49',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('49.5',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));
    INSERT INTO std_size (name, std_group_id, rank) VALUES ('50',(SELECT id FROM std_group WHERE name = 'Shoes'), (select max(rank)+1 from std_size where std_group_id=(SELECT id FROM std_group WHERE name = 'Shoes')));

COMMIT;
