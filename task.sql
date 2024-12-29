-- Вывести к каждому самолету класс обслуживания и количество мест этого класс

SELECT model, fare_conditions, seat_count
FROM aircrafts_data ad
         JOIN (SELECT s.aircraft_code, s.fare_conditions, count(s.seat_no) seat_count
               FROM seats s
               GROUP BY fare_conditions, aircraft_code) seat_counts
              ON seat_counts.aircraft_code = ad.aircraft_code;


-- Найти 3 самых вместительных самолета (модель + кол-во мест)

SELECT model, seat_count
FROM aircrafts_data ad
         JOIN (SELECT s.aircraft_code, count(s.seat_no) seat_count
               FROM seats s
               GROUP BY aircraft_code
               ORDER BY seat_count DESC
               LIMIT 3) seat_counts
              ON ad.aircraft_code = seat_counts.aircraft_code;

-- Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам

SELECT ad.aircraft_code, ad.model, s.seat_no
FROM aircrafts_data ad
         JOIN seats s ON ad.aircraft_code = s.aircraft_code
WHERE ad.model ->> 'ru' = 'Аэробус A321-200'
  AND s.fare_conditions != 'Economy'
ORDER BY s.seat_no;

-- Вывести города в которых больше 1 аэропорта ( код аэропорта, аэропорт, город)

SELECT airport_code, airport_name, city
FROM airports_data ad
WHERE ad.city IN (SELECT city FROM airports_data GROUP BY city HAVING count(airport_code) > 1);


-- Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация

SELECT flight_id,
       flight_no,
       scheduled_departure,
       scheduled_arrival,
       status,
       departure.airport_name,
       arrival.airport_name
FROM flights f
         JOIN airports departure ON f.departure_airport = departure.airport_code
         JOIN airports arrival ON f.arrival_airport = arrival.airport_code
WHERE f.status IN ('Scheduled', 'On Time', 'Delayed')
  AND (departure.city = 'Екатеринбург' AND arrival.city = 'Москва')
  AND f.scheduled_departure =
      (SELECT min(scheduled_departure)
       FROM flights f
                JOIN airports departure ON f.departure_airport = departure.airport_code
                JOIN airports arrival ON f.arrival_airport = arrival.airport_code
       WHERE f.status IN ('Scheduled', 'On Time', 'Delayed')
         AND (departure.city = 'Екатеринбург' AND arrival.city = 'Москва'));

-- используя Common Table Expressions (CTE):
WITH t AS (SELECT flight_id,
                  flight_no,
                  scheduled_departure,
                  scheduled_arrival,
                  status,
                  departure.airport_name,
                  arrival.airport_name
           FROM flights f
                    JOIN airports departure ON f.departure_airport = departure.airport_code
                    JOIN airports arrival ON f.arrival_airport = arrival.airport_code
           WHERE f.status IN ('Scheduled', 'On Time', 'Delayed')
             AND (departure.city = 'Екатеринбург' AND arrival.city = 'Москва'))

SELECT *
FROM t
WHERE scheduled_departure = (SELECT min(scheduled_departure) FROM t);


-- Вывести самый дешевый и дорогой билет и стоимость ( в одном результирующем ответе)

SELECT t.*, amount
FROM tickets t
         JOIN ((SELECT ticket_no, amount
                FROM ticket_flights
                WHERE amount = (SELECT min(amount) FROM ticket_flights)
                LIMIT 1)
               UNION ALL
               (SELECT ticket_no, amount
                FROM ticket_flights
                WHERE amount = (SELECT max(amount) FROM ticket_flights)
                LIMIT 1)) min_max
              ON t.ticket_no = min_max.ticket_no;


-- Вывести информацию о вылете с наибольшей суммарной стоимостью билетов
SELECT f.*, total_amount
FROM flights f
         JOIN (SELECT flight_id, sum(amount) total_amount
               FROM ticket_flights
               GROUP BY flight_id
               ORDER BY total_amount DESC
               LIMIT 1) max_amount
              ON f.flight_id = max_amount.flight_id;


-- Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели, информацию о модели и общую стоимость

SELECT ad.aircraft_code, ad.model, total_amount
FROM aircrafts_data ad
         JOIN (SELECT aircraft_code, sum(amount) total_amount
               FROM flights f
                        JOIN ticket_flights tf ON f.flight_id = tf.flight_id
               GROUP BY f.aircraft_code) aircraft_amount ON ad.aircraft_code = aircraft_amount.aircraft_code
WHERE aircraft_amount.total_amount = (SELECT max(total_amount)
                                      FROM (SELECT sum(amount) total_amount
                                            FROM flights f
                                                     JOIN ticket_flights tf ON f.flight_id = tf.flight_id
                                            GROUP BY f.aircraft_code) aircraft_amount);


-- Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов, информацию о модели самолета, аэропорт назначения, город

WITH arrival_counts AS (SELECT aircraft_code,
                               arrival_airport,
                               count(arrival_airport) airport_count
                        FROM flights f
                        GROUP BY aircraft_code, arrival_airport),

     max_counts AS (SELECT aircraft_code,
                           max(airport_count) max_count
                    FROM arrival_counts
                    GROUP BY aircraft_code)

SELECT max_count, model, airport_name, city
FROM arrival_counts ac
         JOIN max_counts mc ON ac.aircraft_code = mc.aircraft_code AND ac.airport_count = mc.max_count
         JOIN airports_data f ON f.airport_code = ac.arrival_airport
         JOIN aircrafts_data ad ON ad.aircraft_code = ac.aircraft_code;
