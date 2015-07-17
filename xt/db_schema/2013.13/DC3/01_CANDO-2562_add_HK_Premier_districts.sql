--CANDO-2562 : Add Districts and district groups for HongKong

BEGIN WORK;

INSERT INTO country_subdivision_group(name) VALUES
('Hong Kong Island'),
('Kowloon'),
('New Territories'),
('Outlying Islands');

INSERT INTO country_subdivision(country_id, name, country_subdivision_group_id) VALUES
((select id from country where country = 'Hong Kong'), 'Aberdeen', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Admiralty', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Ap Lei Chau', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Causeway Bay',(select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Central', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Chai Wan', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Cyberport', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Deep Water Bay', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Fortress Hill', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Happy Valley', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Heng Fa Chuen', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Kennedy Town', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Mid-Levels', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'North Point', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Pok Fu Lam', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Quarry Bay', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Repulse Bay', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Sai Wan Ho', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Sai Ying Pun', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Shau Kei Wan', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Shek O', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Sheung Wan', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Shouson Hill', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Stanley', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Stubbs Road', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Tai Hang', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Tai Koo', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'The Peak', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Tin Hau', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Wan Chai', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Wong Chuk Hang', (select id from country_subdivision_group where name = 'Hong Kong Island')),
((select id from country where country = 'Hong Kong'), 'Cheung Sha Wan', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Choi Hung', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Choi Wan', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Diamond Hill', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Ho Man Tin', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Hung Hom', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Jordan', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Kowloon Bay', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Kowloon City', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Kowloon Tong', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Kwun Tong', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Lai Chi Kok', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Lam Tin', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Lei Yue Mun', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Lok Fu', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Mei Foo', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Mong Kok', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Ngau Tau Kok', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Prince Edward', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'San Po Kong', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Sham Shui Po', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Shek Kip Mei', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Tai Kwok Tsui', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'To Kwa Wan', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Tsim Sha Tsui', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Tsz Wan Shan', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Whampoa Garden', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Wong Tai Sin', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Yau Ma Tei', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Yau Tong', (select id from country_subdivision_group where name = 'Kowloon')),
((select id from country where country = 'Hong Kong'), 'Fanling', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Fo Tan', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Kwai Chung', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Kwai Fong', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Lau Fau shan', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Lo Wu', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Lok Ma Chau', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Ma On Shan', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Ma Wan', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Sai Kung', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Sha Tin', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Sham Tseng', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Sheung Shui', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Tai Po', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Tai Wai', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Tai Wo', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Tin Shui Wai', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Tseung Kwan O', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Tsing Yi', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Tsuen Wan', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Tuen Mun', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Yuen Long', (select id from country_subdivision_group where name = 'New Territories')),
((select id from country where country = 'Hong Kong'), 'Cheung Chau', (select id from country_subdivision_group where name = 'Outlying Islands')),
((select id from country where country = 'Hong Kong'), 'Lantau Island', (select id from country_subdivision_group where name = 'Outlying Islands')),
((select id from country where country = 'Hong Kong'), 'Lamma Island', (select id from country_subdivision_group where name = 'Outlying Islands')),
((select id from country where country = 'Hong Kong'), 'Ping Chau', (select id from country_subdivision_group where name = 'Outlying Islands')),
((select id from country where country = 'Hong Kong'), 'Po Toi Island', (select id from country_subdivision_group where name = 'Outlying Islands')),
((select id from country where country = 'Hong Kong'), 'Tai O', (select id from country_subdivision_group where name = 'Outlying Islands'));

COMMIT WORK;