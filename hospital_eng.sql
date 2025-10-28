-- To start, let's evaluate each table to identify the available information

SELECT *
FROM patients;

	-- In the patients table we have patient id, name, age, arrival and departure dates, service, and satisfaction level. 
     -- It reflects basic patient information
SELECT *
FROM services_weekly;

	-- Weekly services, we can observe the type of service, available and required beds, as well as rejected patients and satisfaction, 
		-- in addition to staff morale

SELECT *
FROM staff;

	-- Here we observe the number of doctors assigned to each department

SELECT *
FROM staff_schedule;

	-- Here is the schedule for each doctor, the service they were assigned to, and whether they attended the shift or not  
-- With this information, we assume we want to find the causes for insufficient hospital beds and if there is any way to improve this


-- Let's count the number of patients, the initial and final dates of services, and the average satisfaction level

SELECT DISTINCT COUNT(patient_id), min(arrival_date), max(departure_date), AVG(satisfaction),min(satisfaction),max(satisfaction), avg(age)
FROM patients;

-- We have 1000 distinct patients who came in a 1-year period, and their average satisfaction was 79.59, understanding that the minimum assigned was 60 and the maximum 99.
-- Average age of 45 years

-- Let's identify how many patients there were for each specialty and their satisfaction level

SELECT COUNT(patient_id) as cuenta_pacientes, service, AVG(satisfaction), avg(age)
FROM patients
GROUP BY service
ORDER BY cuenta_pacientes DESC;

WITH avg_patients_by_service AS(
SELECT COUNT(patient_id) as cuenta_pacientes
FROM patients
GROUP BY service)
SELECT avg(cuenta_pacientes)
FROM avg_patients_by_service;


-- With this we discovered that the specialties had a fairly even balance in terms of distribution, as did the average satisfaction level

-- Let's calculate the average length of stay for patients
	-- The dates are in STR
	SELECT str_to_date(departure_date, '%Y-%m-%d'),str_to_date(arrival_date, '%Y-%m-%d')
	FROM patients;
    
    UPDATE patients
    SET departure_date = str_to_date(departure_date, '%Y-%m-%d');
    
    UPDATE patients
    SET arrival_date = str_to_date(arrival_date, '%Y-%m-%d');

	ALTER TABLE patients
	MODIFY COLUMN arrival_date date;
    
	ALTER TABLE patients
	MODIFY COLUMN departure_date date;

SELECT
arrival_date,departure_date,
datediff(departure_date,arrival_date)
FROM patients
ORDER BY arrival_date ASC;

SELECT
max(datediff(departure_date,arrival_date)),
min(datediff(departure_date,arrival_date))
FROM patients;

-- Patients spend a maximum of 14 days hospitalized, and a minimum of 1 day

SELECT service,
avg(datedifF(departure_date,arrival_date)) as avg_dias_internados,
avg(satisfaction) as avg_satisfaction
FROM patients
GROUP BY service
ORDER BY avg_dias_internados DESC
;

-- The service with the highest average days hospitalized is surgery and although slight, a small increase in satisfaction is noted as more days pass

SELECT *
FROM services_weekly;
-- Starting to look at weekly services. Let's visualize the sum of rejected and admitted patients each month

SELECT `month`, sum(patients_admitted), sum(patients_refused), avg(patient_satisfaction), avg(staff_morale)
FROM services_weekly
GROUP BY `month`
ORDER BY sum(patients_refused) DESC;

-- We realize that there were rejected patients in all months. 
-- The months with the highest demand were 12, 2, 1 (December, February, and January) by a significant difference compared to the others 

SELECT `month`, sum(patients_admitted), sum(patients_refused), avg(patient_satisfaction), avg(staff_morale)
FROM services_weekly
GROUP BY `month`
ORDER BY avg(patient_satisfaction);

-- Let's see if there is a big difference between the room demand for each area and the available rooms

SELECT service,
max(available_beds) as cap_max,
ROUND(avg(available_beds)) as disp_avg,
max(patients_request) as dem_max,
ROUND(avg(patients_request)) as dem_avg, 
(sum(patients_admitted)+sum(patients_refused)) as total_patients
FROM services_weekly
GROUP BY service;

-- This calculation is revealing, as it tells us that our capacity in many cases does not cover the average demand
	-- Let's calculate the number of times we should increase the size of the facilities to be able to cover the average demand 
		-- and also the difference between the maximum demand and the capacity, to see if there was any unusual event

SELECT service,
max(available_beds) as cap_max,
ROUND(avg(patients_request)) as dem_avg,
ROUND((ROUND(avg(patients_request))/max(available_beds)),2) as expansion_necesaria
FROM services_weekly
GROUP BY service
HAVING ROUND((ROUND(avg(patients_request))/max(available_beds)),2) >= 1;

	-- The emergency service is the most affected, recommending expanding it to 3 times its capacity to be able to cover the average demand
		-- General medicine follows closely, which, although not saturated, would be good to consider its expansion

SELECT service,
max(available_beds) as cap_max,
max(patients_request) as dem_max,
ROUND((max(patients_request)/max(available_beds)),2)
FROM services_weekly
GROUP BY service
ORDER BY ROUND((max(patients_request)/max(available_beds)),2) desc
;

-- All had a demand ratio close to double the capacity, but the emergency service had an x10, let's review this specific service

SELECT *
FROM services_weekly
WHERE service = 'emergency';


WITH calculate AS(
SELECT *
FROM services_weekly
WHERE service = 'emergency'
)

SELECT `month`,
sum(patients_request), 
sum(patients_refused), 
avg(patient_satisfaction),
round(((sum(patients_refused)/sum(patients_request))*100),2) as not_attended_percentaje
FROM calculate
GROUP BY `month`
ORDER BY not_attended_percentaje DESC
;

-- The non-attendance rate was very high every month, where the minimum value was up to 67% and maximum values were 87% in months 2, 3, and 4
	-- I don't see anything distinct, however, let's review the events
    
SELECT count(event), event
FROM services_weekly
GROUP BY event;

-- Let's see if the number of patients requiring care increases considerably compared to when nothing happens

SELECT event, sum(patients_request)
FROM services_weekly
GROUP BY event;

WITH cuenta_event as (
SELECT
 month,
 event,
 patients_request,
 ROW_NUMBER()OVER(PARTITION BY month, event ORDER BY month ASC) AS row_number_by_group 
FROM
    services_weekly)
    
SELECT *
FROM cuenta_event
WHERE row_number_by_group <=1
ORDER by event, month ASC
;

-- Observing the result, the months with "flu" coincide with the months with the highest percentage of NON-attendance. 
-- Which indicates a significant increase in patients due to said event

-- We will see if the team's morale varies with the occurrence of an event

SELECT event, 
ROUND(avg(staff_morale)) as avg_staff_morale,
min(staff_morale) as min_staff_morale,
max(staff_morale) as max_staff_morale
FROM services_weekly
GROUP BY event
ORDER BY avg(staff_morale) ASC;

-- We can observe that the occurrence of the "strike" event significantly influences the team's morale negatively.
	-- While the "donation" event influences it positively


------ STAFF ---- 
SELECT *
FROM staff;

-- Let's see how many professionals there are in each department

SELECT service, count(staff_id)
FROM staff
GROUP BY service
ORDER BY count(staff_id) DESC;

-- We observe that ICU is the service with the most staff, however, we saw above that it was the one with the least demand

-- We will see the number of each professional in each department

SELECT service, 
role,
COUNT(*)
FROM staff
GROUP BY service, role;

-- And now the quantity of each role

SELECT
role,
COUNT(*)
FROM staff
GROUP BY role;

-- This table does not contain much information relevant to our analysis



------ STAFF SCHEDULE---- 

SELECT *
FROM staff_schedule;

-- We will look at absences in general

SELECT present, 
COUNT(*)

FROM staff_schedule
GROUP BY present;

SELECT
   present,
   COUNT(*) AS conteo_por_estado,
    ROUND(CAST(COUNT(*) AS DECIMAL) * 100 / SUM(COUNT(*)) OVER ()) AS porcentaje
FROM
    staff_schedule
GROUP BY
    present;

-- A 40% non-attendance is quite high, we will see the percentage of non-attendance in each service


SELECT
service,
COUNT(CASE WHEN present = 1 THEN 1 END) AS total_presencias, -- Counts "1s"
COUNT(CASE WHEN present = 0 THEN 1 END) AS total_ausencias,  -- Counts "0s"
COUNT(*) AS total_staff,           -- Total count
ROUND((COUNT(CASE WHEN present = 0 THEN 1 END)/COUNT(*))*100,2)
FROM
    staff_schedule
GROUP BY
    service;

-- They are quite even. We will look at non-attendance by week

SELECT
week,
COUNT(CASE WHEN present = 1 THEN 1 END) AS total_presencias, -- Counts "1s"
COUNT(CASE WHEN present = 0 THEN 1 END) AS total_ausencias,  -- Counts "0s"
COUNT(*) AS total_staff,           -- Total count
ROUND((COUNT(CASE WHEN present = 0 THEN 1 END)/COUNT(*))*100,2)
FROM
    staff_schedule

GROUP BY
  week

;

WITH cuenta_ausencia AS(
SELECT week
FROM staff_schedule
group by week
HAVING sum(present) =0)

SELECT COUNT(WEEK)
FROM cuenta_ausencia
;

-- There were 17 weeks where there was no staff, let's see if we can relate it to the events in table 2


WITH cuenta_t1 as (
SELECT
    week,
    service,
    event,
    patients_request,
    ROW_NUMBER() OVER(PARTITION BY week, event ORDER BY week ASC) AS row_number_by_group
   
FROM
    services_weekly),
    cuenta_t2 as(
   SELECT
    week,
    COUNT(CASE WHEN present = 1 THEN 1 END) AS total_presencias, -- Counts "1s"
    COUNT(CASE WHEN present = 0 THEN 1 END) AS total_ausencias,  -- Counts "0s"
    COUNT(*) AS total_staff,           -- Total count
	ROUND((COUNT(CASE WHEN present = 0 THEN 1 END)/COUNT(*))*100,2) as porcentaje_inasistencia
FROM
    staff_schedule

GROUP BY
  week    
    )
    
SELECT cuenta_t1.week,
cuenta_t1.event,
cuenta_t1.service,
cuenta_t2.total_presencias,
cuenta_t2.porcentaje_inasistencia
FROM cuenta_t1
JOIN cuenta_t2
	ON cuenta_t1.week = cuenta_t2.week
WHERE row_number_by_group <=1
AND cuenta_t2.total_presencias =0
ORDER by cuenta_t1.week ASC


;

-- With this extensive query we can see the weeks in which there was total staff absence as well as the events that occurred in those weeks.
	-- We will use a similar query to see how many weeks of non-attendance there were for each event

WITH cuenta_t1 AS(
SELECT DISTINCT
        week,
        service,
        event
    FROM
        services_weekly),
        
cuenta_t2 AS (
SELECT
        week,
        SUM(CASE WHEN present = 1 THEN 1 ELSE 0 END) AS total_ausencias_semana
    FROM
        staff_schedule
    GROUP BY
        week
    HAVING
        SUM(CASE WHEN present = 1 THEN 1 ELSE 0 END) = 0)
SELECT 
cuenta_t1.service,
cuenta_t1.event,
COUNT(cuenta_t1.week)
FROM cuenta_t1
JOIN cuenta_t2
	ON cuenta_t1.week = cuenta_t2.week
GROUP BY cuenta_t1.service,
cuenta_t1.event
ORDER BY COUNT(cuenta_t1.week) DESC;

-- Non-attendance is not directly related to events, as the largest margin of non-attendance is observed when nothing happens  
    
-- Let's analyze the relationship between patient satisfaction and employee morale by service


SELECT t1.service,
t1.avg_sat,
t2.avg_staff_moral
FROM(SELECT service, AVG(satisfaction) as avg_sat
FROM patients
GROUP BY service) as t1
JOIN 
(SELECT service, avg(staff_morale) as avg_staff_moral
FROM services_weekly
GROUP BY service) as t2
ON t1.service = t2.service
ORDER BY t1.avg_sat DESC
;

-- No relationship was found between these parameters

-- CONCLUSIONES --

-- Main Problem: Insufficient Operational Capacity.

-- Physical Capacity (Beds): The Emergency service is the biggest bottleneck, requiring x3 expansion just to cover the average demand. 
	-- Seasonal demand (Months 1, 2, 12 due to Flu) saturates the system, leading to a patient rejection rate of 67%-87% in Emergency.

-- Human Capacity (Staff): Non-attendance is critically high (40% global), and morale is negatively affected by the "Strike" event. 
	-- This drastically reduces the capacity to attend patients during peak demand times.

-- Quality (Satisfaction/Morale): Correlation analysis did not show a direct relationship between patient satisfaction and staff morale by service, 
	-- suggesting that high general satisfaction (79.59) is maintained despite internal problems, but operational risks are unacceptable (high rejections).