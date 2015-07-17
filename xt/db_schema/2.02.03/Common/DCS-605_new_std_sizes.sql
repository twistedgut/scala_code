BEGIN;

-- bump the shoe sizes up by two to add new ones at the start
ALTER TABLE std_size DROP CONSTRAINT std_size_rank_key;
UPDATE std_size SET rank = rank + 2 WHERE std_group_id = (SELECT id FROM std_group WHERE name = 'Shoes');
ALTER TABLE std_size ADD CONSTRAINT std_size_rank_key UNIQUE (rank, std_group_id);

-- add new shoe sizes
INSERT INTO std_size VALUES (default, '35', (SELECT id FROM std_group WHERE name = 'Shoes'), 1);
INSERT INTO std_size VALUES (default, '35.5', (SELECT id FROM std_group WHERE name = 'Shoes'), 2);

-- add new clothing sizes
INSERT INTO std_size VALUES (default, 'XXL', (SELECT id FROM std_group WHERE name = 'Clothing'), 7);
INSERT INTO std_size VALUES (default, 'XXXL', (SELECT id FROM std_group WHERE name = 'Clothing'), 8);

-- bump the clothing sizes up by one to add new one at the start
ALTER TABLE std_size DROP CONSTRAINT std_size_rank_key;
UPDATE std_size SET rank = rank + 1 WHERE std_group_id = (SELECT id FROM std_group WHERE name = 'Clothing');
ALTER TABLE std_size ADD CONSTRAINT std_size_rank_key UNIQUE (rank, std_group_id);
INSERT INTO std_size VALUES (default, 'XXXS', (SELECT id FROM std_group WHERE name = 'Clothing'), 1);


-- add shoe mappings
-- FR
INSERT INTO std_size_mapping VALUES (default, 9, 93, 5, null, (SELECT id FROM std_size WHERE name = '35') );
INSERT INTO std_size_mapping VALUES (default, 9, 94, 5, null, (SELECT id FROM std_size WHERE name = '35.5') );

-- IT
INSERT INTO std_size_mapping VALUES (default, 10, 91, 5, null, (SELECT id FROM std_size WHERE name = '35') );
INSERT INTO std_size_mapping VALUES (default, 10, 92, 5, null, (SELECT id FROM std_size WHERE name = '35.5') );

-- UK
INSERT INTO size VALUES (26, '2.5');
INSERT INTO std_size_mapping VALUES (default, 12, 25, 5, null, (SELECT id FROM std_size WHERE name = '35') );
INSERT INTO std_size_mapping VALUES (default, 12, 26, 5, null, (SELECT id FROM std_size WHERE name = '35.5') );

-- US
INSERT INTO std_size_mapping VALUES (default, 13, 31, 5, null, (SELECT id FROM std_size WHERE name = '35') );
INSERT INTO std_size_mapping VALUES (default, 13, 32, 5, null, (SELECT id FROM std_size WHERE name = '35.5') );


-- add clothing mappings
-- RTW France
INSERT INTO std_size_mapping VALUES (default, 2, 85, 5, null, (SELECT id FROM std_size WHERE name = 'XXXS') );
INSERT INTO std_size_mapping VALUES (default, 2, 113, 5, null, (SELECT id FROM std_size WHERE name = 'XXL') );
INSERT INTO std_size_mapping VALUES (default, 2, 117, 5, null, (SELECT id FROM std_size WHERE name = 'XXXL') );

-- RTW Italy
INSERT INTO std_size_mapping VALUES (default, 3, 93, 5, null, (SELECT id FROM std_size WHERE name = 'XXXS') );
INSERT INTO std_size_mapping VALUES (default, 3, 120, 5, null, (SELECT id FROM std_size WHERE name = 'XXL') );

-- RTW UK
INSERT INTO std_size_mapping VALUES (default, 4, 29, 5, null, (SELECT id FROM std_size WHERE name = 'XXXS') );
INSERT INTO std_size_mapping VALUES (default, 4, 57, 5, null, (SELECT id FROM std_size WHERE name = 'XXL') );

-- RTW US
INSERT INTO std_size_mapping VALUES (default, 5, 22, 5, null, (SELECT id FROM std_size WHERE name = 'XXXS') );
INSERT INTO std_size_mapping VALUES (default, 5, 49, 5, null, (SELECT id FROM std_size WHERE name = 'XXL') );
INSERT INTO std_size_mapping VALUES (default, 5, 53, 5, null, (SELECT id FROM std_size WHERE name = 'XXXL') );

-- RTW JAPAN
INSERT INTO std_size_mapping VALUES (default, 7, 55, 5, null, (SELECT id FROM std_size WHERE name = 'XXL') );
INSERT INTO std_size_mapping VALUES (default, 7, 59, 5, null, (SELECT id FROM std_size WHERE name = 'XXXL') );

-- RTW Danish
INSERT INTO std_size_mapping VALUES (default, 8, 109, 5, null, (SELECT id FROM std_size WHERE name = 'XXL') );
INSERT INTO std_size_mapping VALUES (default, 8, 113, 5, null, (SELECT id FROM std_size WHERE name = 'XXXL') );


-- move any existing size 0 over to XXXS
update variant set std_size_id = (select id from std_size where name = 'XXXS') where size_id = 22;
delete from std_size_mapping where size_id = 22 and std_size_id = (select id from std_size where name = 'XXS');

COMMIT;