-- Purpose: Splitting out the Retail dept to allow greater access control
--  

BEGIN;

insert into department values ((select max(id) + 1 from department), 'Buying');
insert into department values ((select max(id) + 1 from department), 'Merchandising');
insert into department values ((select max(id) + 1 from department), 'Product Merchandising');

update operator set department_id = (select id from department where department = 'Buying') where name in (
'Adriana Chryssicopoulos', 'Charmaine Beaumont-Rixen', 'Ben Matthews', 'Holli Rogers', 'Virginia Castillo', 'Heather Gramston', 'Alice Sanderson', 'Nicola Mellor', 'Simran Sehmi', 'Linda Ayepe', 'Georgina Gainza'
);

update operator set department_id = (select id from department where department = 'Merchandising') where name in (
'Emilie Dumoulin', 'Samara Dadey', 'Paul Brennan', 'Anna Heneback', 'Diane Baker', 'Kathryn Lancaster', 'Nikki Irvine', 'Minal Patel', 'Peter Donald'
);

update operator set department_id = (select id from department where department = 'Product Merchandising') where name in (
'Heather Ross', 'Marisa Capaldi'
);


COMMIT;