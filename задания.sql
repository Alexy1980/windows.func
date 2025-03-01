/**БД 
	- employees	
	name		type	null?
	id			INTEGER	✓
	name		TEXT	✓
	city		TEXT	✓
	department	TEXT	✓
	salary		INTEGER	✓
	
	- expenses
	name	type	null?
	year	INTEGER	✓
	month	INTEGER	✓
	income	INTEGER	✓
	expense	INTEGER	✓
**/

-- Предположим, мы хотим ранжировать сотрудников по имени (по алфавиту от А к Я):
select
	dense_rank() over (order by name asc) as rank,
	name, 
	department, 
	salary
from employees
order by rank, id;

-- Теперь составим рейтинг сотрудников по размеру заработной платы независимо по каждому департаменту

select
	dense_rank() over (partition by department order by salary desc) as rank,
	name, 
	department, 
	salary
from employees
order by department, rank, id;

-- В компании работают сотрудники из Москвы и Самары. Предположим, мы решили ранжировать их по зарплате внутри каждого города. И еще будем ранжировать от меньшей зарплаты к большей

select
	dense_rank() over (partition by city order by salary desc) as rank,
	name, 
	city, 
	salary
from employees
order by city, rank, id;

-- Разобьем сотрудников на три группы в зависимости от размера зарплаты: высокооплачиваемые, средние, низкооплачиваемые.
-- ntile(n) разбивает все записи на n групп и возвращает номер группы для каждой записи

select
	ntile(3) over (order by salary desc) as tile,
	name, 
	department, 
	salary
from employees
order by salary desc, id;

-- Есть таблица сотрудников employees . В компании работают сотрудники из Москвы и Самары. Мы хотим разбить их на две группы по зарплате в каждом из городов

select
	ntile(2) over (order by city asc) as tile,
	name, 
	city, 
	salary
from
(select
	ntile(3) over (order by salary desc) as tile,
	name, 
	city, 
	salary
from employees)
order by city,salary desc;

-- Есть таблица сотрудников employees . Мы хотим узнать самых высокооплачиваемых людей по каждому департаменту

select id,name, department, salary from
(select
    id,
	dense_rank() over (partition by department order by salary desc) as rank,        
	name, 
	department, 
	salary
from
(select
    id,
	ntile(3) over (order by salary desc) as tile,        
	name, 
	department, 
	salary
from employees)
order by salary desc) where rank = 1 order by salary;

-- Разница по зарплате с предыдущим

-- чтобы на каждом шаге подтягивать зарплату предыдущего сотрудника, будем использовать оконную функцию lag()
--Функция lag() возвращает значение из указанного столбца, отстоящее от текущего на указанное количество записей назад. В нашем случае — salary от предыдущей записи

select
	id, 
	name, 
	department, 
	salary,
	lag(salary, 1) over (order by salary) as prev
from employees
order by salary, id;

-- Столбец prev показывает зарплату предыдущего сотрудника. Осталось посчитать разницу между prev и salary в процентах

with emp as (
	select
		id, 
		name, 
		department, 
		salary,
		lag(salary, 1) over (order by salary) as prev
	from employees
)
select
	name, 
	department, 
	salary,
	round((salary - prev)*100.0 / salary) as diff
from emp
order by salary, id;

-- Можно избавиться от промежуточной таблицы emp , подставив вместо prev вызов оконной функции

select
	name, 
	department, 
	salary,
	round(
		(salary - lag(salary, 1) over (order by salary))*100.0 / salary
	) as diff
	from employees
order by salary, id;

-- Есть таблица сотрудников employees . Мы хотим для каждого сотрудника увидеть зарплаты предыдущего и следующего коллеги

select
	id, 
	name, 
	department,
	lag(salary, 1) over (order by salary) as prev,	
	salary,	
	lead(salary, 1) over (order by salary) as next_
from employees order by salary, id;

-- как зарплата сотрудника соотносится с минимальной и максимальной зарплатой в его департаменте
-- Для каждого сотрудника столбец low показывает минимальную зарплату родного департамента, а столбец high — максимальную

select
	name, 
	department, 
	salary,
	first_value(salary) over w as low,
	last_value(salary) over w as high
from employees
window w as (
	partition by department
	order by salary
	-- настроим окно, чтобы фрейм в точности совпадал с секцией (департаментом)
	-- что благодаря rows between фрейм совпадает с секцией, а значит last_value() вернет максимальную зарплату по департаменту
	rows between unbounded preceding and unbounded following
)
order by department, salary, id;

-- Есть таблица сотрудников employees . Мы хотим для каждого сотрудника увидеть, сколько процентов составляет его зарплата от максимальной в городе

with emp as (
	select 
		name, 
		city, 
		salary,
		last_value(salary) over (partition by city order by salary rows between unbounded preceding and unbounded following) as max_v
	from employees
)
select
	name, 
	city, 
	salary,
	round(salary * 100 / max_v, 3) as perc
from emp
order by city, salary;

/*
name	city	salary	perc
Grace	Berlin	90		75
Cindy	Berlin	96		80
Alice	Berlin	100		83
Irene	Berlin	104		86
Frank	Berlin	120		100
Diane	London	70		67
Bob		London	78		75
Emma	London	84		80
Dave	London	96		92
Henry	London	104		100
*/

-- фонд оплаты труда — денежная сумма, которая ежемесячно уходит на выплату зарплат сотрудникам. Посмотрим, какой процент от этого фонда составляет зарплата каждого сотрудника

select
name, department, salary,
sum(salary) over w as fund,
round(salary * 100.0 / sum(salary) over w) as perc
from employees

window w as (partition by department)
order by department, salary, id;

/*
name	department	salary	fund	perc
Дарья		hr			70	148		47
Борис		hr			78	148		53
Елена		it			84	502		17
Ксения		it			90	502		18
Леонид		it			104	502		21
Марина		it			104	502		21
Иван		it			120	502		24
Вероника	sales		96	292		33
Григорий	sales		96	292		33
Анна		sales		100	292		34
*/

-- Есть таблица сотрудников employees . Мы хотим для каждого сотрудника увидеть, сколько процентов составляет его зарплата от общего фонда труда по городу
select
name, city, salary,
sum(salary) over w as fund,
round(salary * 100.0 / sum(salary) over w) as perc
from employees

window w as (partition by city)
order by city, salary, id;

-- Есть таблица сотрудников employees . Мы хотим для каждого сотрудника увидеть:
-- сколько человек трудится в его отделе ( emp_cnt );
-- какая средняя зарплата по отделу ( sal_avg );
-- на сколько процентов отклоняется его зарплата от средней по отделу ( diff ).

select
name, department, salary,
count(salary) over w as emp_cnt,
round(avg(salary) over w,2) as sal_avg,
round(-100+salary * 100.0 / avg(salary) over w,2) as diff
from employees

window w as (partition by department)
order by department, salary, id;


-- мы хотим оставить в отчете только самарских сотрудников

with emp as (
select
name, city, salary,
sum(salary) over w as fund
from employees
window w as (partition by department)
order by department, salary, id
)
select name, salary, fund
from emp
where city = 'Самара';

-- Есть таблица доходов-расходов expenses . Мы хотим рассчитать скользящее среднее по доходам за предыдущий и текущий месяц

select
year, month, income,
round(avg(income) over w,2) as roll_avg
from expenses
window w as (
order by year, month
rows between 1 preceding and 1 following
)
order by year, month;

-- определение окна может быть пустым Такое окно включает все строки, так что emp_count покажет общее количество сотрудников, а fund — общий фонд оплаты труда по всем записям employees

select
name, department, salary,
count(*) over () as emp_count,
sum(salary) over () as fund
from employees
order by department, salary, id;

-- рассчитать кумулятивные показатели
-- t_income показывает доходы нарастающим итогом, t_expense — расходы, а t_profit — прибыль
/*
- кумулятивный доход за январь = январь;
- за февраль = январь + февраль;
- за март = январь + февраль + март;
- за апрель = январь + февраль + март + апрель;
- и так далее.
*/
select
year, month, income, expense,
sum(income) over w as t_income,
sum(expense) over w as t_expense,
(sum(income) over w) - (sum(expense) over w) as t_profit
from expenses
window w as (
order by year, month
rows between unbounded preceding and current row
)
order by year, month;

-- посчитать фонд оплаты труда нарастающим итогом независимо для каждого департамента

select
id,
name,
department,
salary,
sum(salary) over w as total
from employees
window w as (
partition by department
rows between unbounded preceding and current row
)
order by department , salary , id;

-- Фреймы main