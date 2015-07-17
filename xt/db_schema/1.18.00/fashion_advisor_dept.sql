
-- create new department and move users across

insert into department values ((select max(id) + 1 from department), 'Fashion Advisor');

update operator set department_id = (select id from department where department = 'Fashion Advisor') where name in ('Jo Heller', 'Lauren Elrick', 'Marta Messias', 'Olivia Young', 'Iman Leslie', 'Lakeisha Williams');

