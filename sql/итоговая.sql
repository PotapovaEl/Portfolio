
--1 В каких городах больше одного аэропорта?

select city, count(*)
from airports
group by city
having count(*) > 1;

--2 В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

select ap.airport_name 
from airports ap
left join flights fl on ap.airport_code = fl.departure_airport
where fl.aircraft_code = (
	select ac.aircraft_code 
	from aircrafts ac 
	order by "range" desc
	limit 1)
group by ap.airport_name;

--3 Вывести 10 рейсов с максимальным временем задержки вылета

select fl.flight_id, (fl.actual_departure - fl.scheduled_departure) as del_dep
from flights fl
where fl.status = 'Arrived'
order by  del_dep desc
limit 10;

--4 Были ли брони, по которым не были получены посадочные талоны?

select count(bookings.book_ref)
from bookings
full outer join tickets on bookings.book_ref = tickets.book_ref
full outer join boarding_passes on boarding_passes.ticket_no = tickets.ticket_no
where boarding_passes.boarding_no is null;

--5 Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
--Добавьте столбец с накопительным итогом - суммарное количество вывезенных пассажиров из аэропорта за день. 
Т.е. в этом столбце должна отражаться сумма - 
--сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах за сегодняшний день

select ts.flight_id,
ts.scheduled_departure,
ts.departure_airport,
(ts.total_seat - ts.fact_passengers) as free_seats,
round (100*((ts.total_seat - ts.fact_passengers)::numeric / ts.total_seat::numeric),0) as percent_freeseats,
sum (ts.fact_passengers) over (partition by ts.departure_airport,  date_trunc('day', ts.scheduled_departure) order by ts.scheduled_departure ) as day_sum
from (select f.flight_id, f.scheduled_departure, f.departure_airport, count(tf.ticket_no) as fact_passengers, ( 
	select count(s.seat_no)
	from seats s
	where s.aircraft_code = f.aircraft_code
	) as total_seat
	from flights f
	join ticket_flights tf on f.flight_id = tf.flight_id
	group by f.flight_id, f.scheduled_departure, f.departure_airport) as ts;
	
--6 Найдите процентное соотношение перелетов по типам самолетов от общего количества.

select ac.model,
round ((100*count(flight_id)::numeric/(select count(flight_id)::numeric from flights fl)),2)  
from 
flights fl
left join aircrafts ac on fl.aircraft_code = ac.aircraft_code 
group by ac.model;

--7 Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

with cte_e as (
select flight_id, max (amount) as economy
from ticket_flights tf 
where fare_conditions = 'Economy'
group by flight_id, fare_conditions),
cte_b as (
select flight_id, min (amount) as business 
from ticket_flights tf 
where fare_conditions = 'Business'
group by flight_id, fare_conditions)
select ap.city 
from airports ap
left join flights fl on ap.airport_code = fl.departure_airport 
left join cte_e on fl.flight_id = cte_e.flight_id
left join cte_b on cte_e.flight_id = cte_b.flight_id
where cte_e.economy > cte_b.business
group by ap.city;

--8 Между какими городами нет прямых рейсов?

create view route as 
	select distinct a.city as departure_city , b.city as arrival_city, a.city||'-'||b.city as route 
	from airports as a, (select city from airports) as b
	where a.city != b.city
	order by route
	
create view direct_flight as 
	select distinct a.city as departure_city, aa.city as arrival_city, a.city||'-'|| aa.city as route  
	from flights as f
	inner join airports as a on f.departure_airport=a.airport_code
	inner join airports as aa on f.arrival_airport=aa.airport_code
	order by route
	
select r.* 
from route as r
except 
select df.* 
from direct_flight as df

--9 Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы

with cte_dist as
(select dep.airport_name as departure_airport, dep.city as departure_city, dep.longitude, dep.latitude, 
   arr.airport_name as arrival_airport, arr.city as arrival_city, arr.longitude, arr.latitude,
   round((acos(sin(radians(dep.latitude)) * sin(radians(arr.latitude)) + cos(radians(dep.latitude)) * cos(radians(arr.latitude)) * cos(radians(dep.longitude) - radians(arr.longitude)))*6371)::numeric,0) as distance,
   f.aircraft_code 
   from flights f,
    airports dep,
    airports arr 
  where f.departure_airport = dep.airport_code and f.arrival_airport = arr.airport_code)
 select ac.model, ac.range, distance, departure_airport, departure_city, arrival_airport, arrival_city  
 from cte_dist   
left join aircrafts ac on cte_dist.aircraft_code = ac.aircraft_code
group by ac.model, ac.range, distance, departure_airport, departure_city, arrival_airport, arrival_city
order by departure_airport;

