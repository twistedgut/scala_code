BEGIN WORK;

CREATE TABLE country_subdivision (
    id                          SERIAL NOT NULL PRIMARY KEY,
    country_id                  INTEGER REFERENCES country(id),
    iso                         CHARACTER VARYING(10),
    name                        CHARACTER VARYING(128) NOT NULL UNIQUE
);

INSERT INTO country_subdivision(country_id, iso, name) VALUES
((select id from country where country = 'United States'), 'AL', 'Alabama'),
((select id from country where country = 'United States'), 'AK', 'Alaska'),
((select id from country where country = 'United States'), 'AZ', 'Arizona'),
((select id from country where country = 'United States'), 'AR', 'Arkansas'),
((select id from country where country = 'United States'), 'CA', 'California'),
((select id from country where country = 'United States'), 'CO', 'Colorado'),
((select id from country where country = 'United States'), 'CT', 'Connecticut'),
((select id from country where country = 'United States'), 'DE', 'Delaware'),
((select id from country where country = 'United States'), 'FL', 'Florida'),
((select id from country where country = 'United States'), 'GA', 'Georgia'),
((select id from country where country = 'United States'), 'HI', 'Hawaii'),
((select id from country where country = 'United States'), 'ID', 'Idaho'),
((select id from country where country = 'United States'), 'IL', 'Illinois'),
((select id from country where country = 'United States'), 'IN', 'Indiana'),
((select id from country where country = 'United States'), 'IA', 'Iowa'),
((select id from country where country = 'United States'), 'KS', 'Kansas'),
((select id from country where country = 'United States'), 'KY', 'Kentucky'),
((select id from country where country = 'United States'), 'LA', 'Louisiana'),
((select id from country where country = 'United States'), 'ME', 'Maine'),
((select id from country where country = 'United States'), 'MD', 'Maryland'),
((select id from country where country = 'United States'), 'MA', 'Massachusetts'),
((select id from country where country = 'United States'), 'MI', 'Michigan'),
((select id from country where country = 'United States'), 'MN', 'Minnesota'),
((select id from country where country = 'United States'), 'MS', 'Mississippi'),
((select id from country where country = 'United States'), 'MO', 'Missouri'),
((select id from country where country = 'United States'), 'MT', 'Montana'),
((select id from country where country = 'United States'), 'NE', 'Nebraska'),
((select id from country where country = 'United States'), 'NV', 'Nevada'),
((select id from country where country = 'United States'), 'NH', 'New Hampshire'),
((select id from country where country = 'United States'), 'NJ', 'New Jersey'),
((select id from country where country = 'United States'), 'NM', 'New Mexico'),
((select id from country where country = 'United States'), 'NY', 'New York'),
((select id from country where country = 'United States'), 'NC', 'North Carolina'),
((select id from country where country = 'United States'), 'ND', 'North Dakota'),
((select id from country where country = 'United States'), 'OH', 'Ohio'),
((select id from country where country = 'United States'), 'OK', 'Oklahoma'),
((select id from country where country = 'United States'), 'OR', 'Oregon'),
((select id from country where country = 'United States'), 'PA', 'Pennsylvania'),
((select id from country where country = 'United States'), 'RI', 'Rhode Island'),
((select id from country where country = 'United States'), 'SC', 'South Carolina'),
((select id from country where country = 'United States'), 'SD', 'South Dakota'),
((select id from country where country = 'United States'), 'TN', 'Tennessee'),
((select id from country where country = 'United States'), 'TX', 'Texas'),
((select id from country where country = 'United States'), 'UT', 'Utah'),
((select id from country where country = 'United States'), 'VT', 'Vermont'),
((select id from country where country = 'United States'), 'VA', 'Virginia'),
((select id from country where country = 'United States'), 'WA', 'Washington'),
((select id from country where country = 'United States'), 'WV', 'West Virginia'),
((select id from country where country = 'United States'), 'WI', 'Wisconsin'),
((select id from country where country = 'United States'), 'WY', 'Wyoming'),
((select id from country where country = 'United States'), 'AS', 'American Samoa'),
((select id from country where country = 'United States'), 'DC', 'District of Columbia'),
((select id from country where country = 'United States'), 'GU', 'Guam'),
((select id from country where country = 'United States'), 'MP', 'Northern Mariana Islands'),
((select id from country where country = 'United States'), 'PR', 'Puerto Rico'),
((select id from country where country = 'United States'), 'VI', 'The United States Virgin Islands');


ALTER TABLE country_subdivision OWNER             TO postgres;
GRANT ALL ON TABLE country_subdivision            TO postgres;
GRANT ALL ON TABLE country_subdivision            TO www;
GRANT ALL ON SEQUENCE country_subdivision_id_seq  TO postgres;
GRANT ALL ON SEQUENCE country_subdivision_id_seq  TO www;

commit;
