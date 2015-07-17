-- Purpose:
--  

BEGIN;


create table size_scheme_variant_size ( 
	id serial primary key unique,
	size_scheme_id integer references size_scheme(id) NOT NULL,
	size_id integer references size(id) NOT NULL,
	designer_size_id integer references size(id) NOT NULL,
	position integer not null
	);

grant all on size_scheme_variant_size to www;
grant all on size_scheme_variant_size_id_seq to www;

insert into size_scheme_variant_size values (default, 2, 10, 89, 1);
insert into size_scheme_variant_size values (default, 2, 11, 93, 2);
insert into size_scheme_variant_size values (default, 2, 12, 97, 3);
insert into size_scheme_variant_size values (default, 2, 13, 101, 4);
insert into size_scheme_variant_size values (default, 2, 14, 105, 5);
insert into size_scheme_variant_size values (default, 2, 15, 109, 6);
insert into size_scheme_variant_size values (default, 2, 16, 113, 7);

insert into size_scheme_variant_size values (default, 3, 9, 93, 1);
insert into size_scheme_variant_size values (default, 3, 10, 97, 2);
insert into size_scheme_variant_size values (default, 3, 11, 101, 3);
insert into size_scheme_variant_size values (default, 3, 12, 105, 4);
insert into size_scheme_variant_size values (default, 3, 13, 109, 5);
insert into size_scheme_variant_size values (default, 3, 14, 113, 6);
insert into size_scheme_variant_size values (default, 3, 15, 117, 7);
insert into size_scheme_variant_size values (default, 3, 16, 120, 8);

insert into size_scheme_variant_size values (default, 4, 10, 33, 1);
insert into size_scheme_variant_size values (default, 4, 11, 37, 2);
insert into size_scheme_variant_size values (default, 4, 12, 41, 3);
insert into size_scheme_variant_size values (default, 4, 13, 45, 4);
insert into size_scheme_variant_size values (default, 4, 14, 49, 5);
insert into size_scheme_variant_size values (default, 4, 15, 53, 6);
insert into size_scheme_variant_size values (default, 4, 16, 57, 7);

insert into size_scheme_variant_size values (default, 5, 10, 22, 1);
insert into size_scheme_variant_size values (default, 5, 11, 25, 2);
insert into size_scheme_variant_size values (default, 5, 12, 29, 3);
insert into size_scheme_variant_size values (default, 5, 13, 33, 4);
insert into size_scheme_variant_size values (default, 5, 14, 37, 5);
insert into size_scheme_variant_size values (default, 5, 15, 41, 6);
insert into size_scheme_variant_size values (default, 5, 16, 45, 7);

insert into size_scheme_variant_size values (default, 6, 11, 11, 1);
insert into size_scheme_variant_size values (default, 6, 12, 12, 2);
insert into size_scheme_variant_size values (default, 6, 13, 13, 3);
insert into size_scheme_variant_size values (default, 6, 14, 14, 4);
insert into size_scheme_variant_size values (default, 6, 15, 15, 5);
insert into size_scheme_variant_size values (default, 6, 16, 16, 6);

insert into size_scheme_variant_size values (default, 7, 10, 31, 1);
insert into size_scheme_variant_size values (default, 7, 11, 35, 2);
insert into size_scheme_variant_size values (default, 7, 12, 39, 3);
insert into size_scheme_variant_size values (default, 7, 13, 43, 4);
insert into size_scheme_variant_size values (default, 7, 14, 47, 5);
insert into size_scheme_variant_size values (default, 7, 15, 51, 6);

insert into size_scheme_variant_size values (default, 8, 10, 85, 1);
insert into size_scheme_variant_size values (default, 8, 11, 89, 2);
insert into size_scheme_variant_size values (default, 8, 12, 93, 3);
insert into size_scheme_variant_size values (default, 8, 13, 97, 4);
insert into size_scheme_variant_size values (default, 8, 14, 101, 5);
insert into size_scheme_variant_size values (default, 8, 15, 105, 6);

insert into size_scheme_variant_size values (default, 9, 95, 95, 1);
insert into size_scheme_variant_size values (default, 9, 96, 96, 2);
insert into size_scheme_variant_size values (default, 9, 97, 97, 3);
insert into size_scheme_variant_size values (default, 9, 98, 98, 4);
insert into size_scheme_variant_size values (default, 9, 99, 99, 5);
insert into size_scheme_variant_size values (default, 9, 100, 100, 6);
insert into size_scheme_variant_size values (default, 9, 101, 101, 7);
insert into size_scheme_variant_size values (default, 9, 102, 102, 8);
insert into size_scheme_variant_size values (default, 9, 103, 103, 9);
insert into size_scheme_variant_size values (default, 9, 104, 104, 10);
insert into size_scheme_variant_size values (default, 9, 105, 105, 11);

insert into size_scheme_variant_size values (default, 10, 93, 93, 1);
insert into size_scheme_variant_size values (default, 10, 94, 94, 2);
insert into size_scheme_variant_size values (default, 10, 95, 95, 3);
insert into size_scheme_variant_size values (default, 10, 96, 96, 4);
insert into size_scheme_variant_size values (default, 10, 97, 97, 5);
insert into size_scheme_variant_size values (default, 10, 98, 98, 6);
insert into size_scheme_variant_size values (default, 10, 99, 99, 7);
insert into size_scheme_variant_size values (default, 10, 100, 100, 8);
insert into size_scheme_variant_size values (default, 10, 101, 101, 9);
insert into size_scheme_variant_size values (default, 10, 102, 102, 10);
insert into size_scheme_variant_size values (default, 10, 103, 103, 11);
insert into size_scheme_variant_size values (default, 10, 104, 104, 12);
insert into size_scheme_variant_size values (default, 10, 105, 105, 13);

insert into size_scheme_variant_size values (default, 12, 27, 27, 1);
insert into size_scheme_variant_size values (default, 12, 28, 28, 2);
insert into size_scheme_variant_size values (default, 12, 29, 29, 3);
insert into size_scheme_variant_size values (default, 12, 30, 30, 4);
insert into size_scheme_variant_size values (default, 12, 31, 31, 5);
insert into size_scheme_variant_size values (default, 12, 32, 32, 6);
insert into size_scheme_variant_size values (default, 12, 33, 33, 7);
insert into size_scheme_variant_size values (default, 12, 34, 34, 8);
insert into size_scheme_variant_size values (default, 12, 35, 35, 9);
insert into size_scheme_variant_size values (default, 12, 36, 36, 10);
insert into size_scheme_variant_size values (default, 12, 37, 37, 11);

insert into size_scheme_variant_size values (default, 13, 33, 33, 1);
insert into size_scheme_variant_size values (default, 13, 34, 34, 2);
insert into size_scheme_variant_size values (default, 13, 35, 35, 3);
insert into size_scheme_variant_size values (default, 13, 36, 36, 4);
insert into size_scheme_variant_size values (default, 13, 37, 37, 5);
insert into size_scheme_variant_size values (default, 13, 38, 38, 6);
insert into size_scheme_variant_size values (default, 13, 39, 39, 7);
insert into size_scheme_variant_size values (default, 13, 40, 40, 8);
insert into size_scheme_variant_size values (default, 13, 41, 41, 9);
insert into size_scheme_variant_size values (default, 13, 42, 42, 10);
insert into size_scheme_variant_size values (default, 13, 43, 43, 11);


insert into size_scheme_variant_size values (default, 14, 22, 22, 1);
insert into size_scheme_variant_size values (default, 14, 24, 24, 2);
insert into size_scheme_variant_size values (default, 14, 25, 25, 3);
insert into size_scheme_variant_size values (default, 14, 27, 27, 4);
insert into size_scheme_variant_size values (default, 14, 29, 29, 5);
insert into size_scheme_variant_size values (default, 14, 31, 31, 6);
insert into size_scheme_variant_size values (default, 14, 33, 33, 7);

insert into size_scheme_variant_size values (default, 15, 5, 5, 1);


insert into size_scheme_variant_size values (default, 16, 12, 12, 1);
insert into size_scheme_variant_size values (default, 16, 13, 13, 2);
insert into size_scheme_variant_size values (default, 16, 14, 14, 3);

insert into size_scheme_variant_size values (default, 17, 209, 209, 1);
insert into size_scheme_variant_size values (default, 17, 210, 210, 2);
insert into size_scheme_variant_size values (default, 17, 211, 211, 3);
insert into size_scheme_variant_size values (default, 17, 212, 212, 4);
insert into size_scheme_variant_size values (default, 17, 213, 213, 5);
insert into size_scheme_variant_size values (default, 17, 214, 214, 6);

insert into size_scheme_variant_size values (default, 18, 25, 25, 1);
insert into size_scheme_variant_size values (default, 18, 29, 29, 2);
insert into size_scheme_variant_size values (default, 18, 33, 33, 3);
insert into size_scheme_variant_size values (default, 18, 37, 37, 4);
insert into size_scheme_variant_size values (default, 18, 41, 41, 5);
insert into size_scheme_variant_size values (default, 18, 45, 45, 6);

insert into size_scheme_variant_size values (default, 19, 33, 33, 1);
insert into size_scheme_variant_size values (default, 19, 34, 34, 2);
insert into size_scheme_variant_size values (default, 19, 35, 35, 3);
insert into size_scheme_variant_size values (default, 19, 36, 36, 4);
insert into size_scheme_variant_size values (default, 19, 37, 37, 5);

insert into size_scheme_variant_size values (default, 20, 12, 12, 1);
insert into size_scheme_variant_size values (default, 20, 13, 13, 2);
insert into size_scheme_variant_size values (default, 20, 14, 14, 3);


insert into size_scheme_variant_size values (default, 21, 69, 69, 1);
insert into size_scheme_variant_size values (default, 21, 71, 71, 2);
insert into size_scheme_variant_size values (default, 21, 73, 73, 3);
insert into size_scheme_variant_size values (default, 21, 75, 75, 4);
insert into size_scheme_variant_size values (default, 21, 77, 77, 5);
insert into size_scheme_variant_size values (default, 21, 79, 79, 6);
insert into size_scheme_variant_size values (default, 21, 81, 81, 7);
insert into size_scheme_variant_size values (default, 21, 83, 83, 8);
insert into size_scheme_variant_size values (default, 21, 85, 85, 9);
insert into size_scheme_variant_size values (default, 21, 87, 87, 10);
insert into size_scheme_variant_size values (default, 21, 89, 89, 11);

insert into size_scheme_variant_size values (default, 22, 240, 240, 1);
insert into size_scheme_variant_size values (default, 22, 13, 13, 2);
insert into size_scheme_variant_size values (default, 22, 14, 14, 3);
insert into size_scheme_variant_size values (default, 22, 15, 15, 4);
insert into size_scheme_variant_size values (default, 22, 16, 16, 5);

insert into size_scheme_variant_size values (default, 23, 230, 230, 1);
insert into size_scheme_variant_size values (default, 23, 231, 231, 2);

insert into size_scheme_variant_size values (default, 24, 10, 10, 1);
insert into size_scheme_variant_size values (default, 24, 11, 11, 2);
insert into size_scheme_variant_size values (default, 24, 12, 12, 3);
insert into size_scheme_variant_size values (default, 24, 13, 13, 4);
insert into size_scheme_variant_size values (default, 24, 14, 14, 5);
insert into size_scheme_variant_size values (default, 24, 15, 15, 6);
insert into size_scheme_variant_size values (default, 24, 16, 16, 6);

COMMIT;