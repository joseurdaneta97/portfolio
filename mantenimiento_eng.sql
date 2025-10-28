SELECT *
FROM mtt_camiones;

-- This dataset contains maintenance records for a fleet of equipment, including technical details, unit numbers, and more.
-- The initial step is to clean the data by applying the correct format and then proceed with the analysis.

---- DATA CLEANING & TRANSFORMATION ----

-- 1. Date column is currently stored as text (STR).

SELECT FECHA,
str_to_date(FECHA, '%d/ %m/ %Y')
FROM mtt_camiones;

UPDATE mtt_camiones
SET FECHA = str_to_date(FECHA, '%d/ %m/ %Y');

ALTER TABLE mtt_camiones
MODIFY COLUMN FECHA date;

-- The FECHA column format has been successfully modified to 'date', and values have been updated to match.

-- 2. Check for duplicate records

SELECT COUNT(*)
FROM mtt_camiones;

-- 634 total records

SELECT `ï»¿EQUIPO`, FECHA, `NUMERO OTM`, `OPERACION`, COUNT(*)
FROM mtt_camiones
GROUP BY `ï»¿EQUIPO`,FECHA, `NUMERO OTM`, `OPERACION`
HAVING COUNT(*)>1;

SELECT *
FROM mtt_camiones
WHERE `ï»¿EQUIPO`='HT159'
AND FECHA = '2024-02-13'
;

-- We found several duplicate rows, so we'll create a table copy to perform these modifications

CREATE TABLE `mtt_camiones_copy` (
`ï»¿EQUIPO` text,
`UBICACION TECNICA` text,
`NUMERO OTM` int DEFAULT NULL,
`GLOSA` text,
`FECHA` date DEFAULT NULL,
`CLASE DE OTM` text,
`RESPONSABLE` text,
`OPERACION` int DEFAULT NULL,
`TIEMPO DE REPARACION` int DEFAULT NULL,
`HORAS HOMBRE` int DEFAULT NULL,
`DENOMINACION DEL SISTEMA` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT *
FROM mtt_camiones_copy;

INSERT INTO mtt_camiones_copy
SELECT *
FROM mtt_camiones;

-- Now we delete the duplicate rows by using a CTE to count and rank identical records

WITH duplicado AS (
SELECT `ï»¿EQUIPO`,
		FECHA,
		`NUMERO OTM`,
        `OPERACION`,
        ROW_NUMBER() OVER(PARTITION BY`ï»¿EQUIPO`,
        FECHA,
        `NUMERO OTM`,
        `OPERACION` ORDER BY FECHA) as row_col
FROM mtt_camiones_copy)

DELETE FROM mtt_camiones_copy
WHERE (`ï»¿EQUIPO`, FECHA, `NUMERO OTM`, `OPERACION`)
	IN
		(SELECT`ï»¿EQUIPO`, FECHA, `NUMERO OTM`, `OPERACION` 
    FROM duplicado 
    WHERE row_col > 1);

-- The duplicate rows have been successfully removed. Now we verify the final count.

SELECT `ï»¿EQUIPO`, FECHA, `NUMERO OTM`, `OPERACION`, COUNT(*)
FROM mtt_camiones_copy
GROUP BY `ï»¿EQUIPO`,FECHA, `NUMERO OTM`, `OPERACION`
HAVING COUNT(*)>1;

SELECT COUNT(*)
FROM mtt_camiones_copy;

-- Final count is 622 records, meaning 12 duplicates were eliminated.


-- 3. Data Type Consistency Check: The columns needed for calculations, 'TIEMPO DE REPARACION' and 'HORAS HOMBRE', are confirmed to be in INT format.
-- Data type cleaning is complete.

-- 4. Column Name Standardization (Renaming to snake_case)

ALTER TABLE mtt_camiones_copy
RENAME COLUMN `ï»¿EQUIPO` TO equipo,
RENAME COLUMN `UBICACION TECNICA` TO ubicacion_tecnica,
RENAME COLUMN `NUMERO OTM` TO numero_otm,
RENAME COLUMN `GLOSA` TO glosa,
RENAME COLUMN `FECHA` TO fecha,
RENAME COLUMN `CLASE DE OTM` TO clase_otm,
RENAME COLUMN `RESPONSABLE` TO responsable,
RENAME COLUMN `OPERACION` TO operacion,
RENAME COLUMN `TIEMPO DE REPARACION` TO tiempo_reparacion,
RENAME COLUMN `HORAS HOMBRE` TO horas_hombre,
RENAME COLUMN `DENOMINACION DEL SISTEMA` TO denominacion_sistema;


-- 5. Creating a Calculated Column: Personnel Involved (Hours Man / Repair Time)

SELECT tiempo_reparacion,
		horas_hombre,
        ROUND(horas_hombre/tiempo_reparacion) as personal_involucrado
FROM mtt_camiones_copy;

ALTER TABLE mtt_camiones_copy
ADD COLUMN personal_involucrado int AFTER horas_hombre;

UPDATE mtt_camiones_copy
SET personal_involucrado = ROUND(horas_hombre/tiempo_reparacion);


-- 6. Text Standardization and Categorization
-- Grouping system denominations for consistency


SELECT DISTINCT denominacion_sistema
FROM mtt_camiones_copy;


SELECT DISTINCT denominacion_sistema
FROM mtt_camiones_copy
WHERE denominacion_sistema LIKE '%cami%';

-- Multiple entries contain the word 'camion' and will be unified under 'CAMION'

UPDATE mtt_camiones_copy
SET denominacion_sistema = 'CAMION'
WHERE denominacion_sistema LIKE '%cami%';

UPDATE mtt_camiones_copy
SET denominacion_sistema = 'PLATAFORMA'
WHERE denominacion_sistema LIKE '%plata%';

UPDATE mtt_camiones_copy
SET denominacion_sistema = 'BARRA LINK INFERIOR'
WHERE denominacion_sistema LIKE '%barra%';

UPDATE mtt_camiones_copy
SET denominacion_sistema = 'SISTEMA CABINA'
WHERE denominacion_sistema LIKE '%cabina%';

UPDATE mtt_camiones_copy
SET denominacion_sistema = 'CHASIS'
WHERE denominacion_sistema LIKE '%chasi%';

UPDATE mtt_camiones_copy
SET denominacion_sistema = upper('CHASIS')
WHERE denominacion_sistema LIKE '%chasi%';


-- Data cleaning and transformation process is now complete.

---- ANALYSIS ----


SELECT *
FROM mtt_camiones_copy;

-- 1. Total Number of Equipment Units

SELECT COUNT(distinct equipo)
FROM mtt_camiones_copy;

-- 121 distinct equipment units

-- 2. Date Range Analysis

SELECT MIN(fecha) as fecha_inicio,
MAX(fecha) as fecha_fin,
datediff(MAX(fecha),MIN(fecha)) as fecha_rango
FROM mtt_camiones_copy;

-- Records cover a total of 342 days, from 2023-02-14 to 2024-01-22.

-- 3. Work Order Type (OTM Class) Distribution

SELECT clase_otm,
COUNT(*) AS cuenta_otm
FROM mtt_camiones_copy
GROUP BY clase_otm;

-- 4. Classification by System Name (Count and Percentage)

SELECT denominacion_sistema,
COUNT(denominacion_sistema) as cuenta_denominacion,
round((COUNT(denominacion_sistema)/(SELECT count(*) FROM mtt_camiones_copy))*100,2) as porcentaje_del_total
FROM mtt_camiones_copy
GROUP BY denominacion_sistema
ORDER BY cuenta_denominacion DESC;

-- We observe that the systems requiring the highest volume of maintenance are 'CHASIS', 'TOLVA', and 'BARRA LINK INFERIOR'.


-- Having performed the basic calculations to understand the sample size, classifications, and necessary metrics,
	-- we can now proceed with core business analysis queries.

SELECT *
FROM mtt_camiones_copy;

-- 1. Total and Average Repair Time per Equipment Unit

SELECT equipo,
SUM(tiempo_reparacion) AS tiempo_reparacion_total ,
ROUND(AVG(tiempo_reparacion)) as tiempo_reparacion_promedio
FROM mtt_camiones_copy
GROUP BY equipo
ORDER BY tiempo_reparacion_total DESC;


-- 2. Repair Time Trends by Year and Month

SELECT year(FECHA),
SUM(tiempo_reparacion)
FROM mtt_camiones_copy
GROUP BY year(fecha);

SELECT year(fecha),
MONTH(fecha),
SUM(tiempo_reparacion)
FROM mtt_camiones_copy
GROUP BY year(fecha), MONTH(fecha);

SELECT year(fecha) AS año,
MONTH(fecha) as mes,
SUM(tiempo_reparacion) as tiempo_total_reparacion
FROM mtt_camiones_copy
GROUP BY year(FECHA), MONTH(FECHA)
ORDER BY tiempo_total_reparacion DESC;

-- We observe that the last quarter of 2023 saw the highest total repair time, with a peak in October.

-- 3. Technicians with the Highest Repair Time and Average Assigned Personnel

SELECT responsable,
SUM(tiempo_reparacion) as tiempo_total_reparacion,
ROUND(AVG(personal_involucrado)) as personal_asignado_prom
FROM mtt_camiones_copy
GROUP BY RESPONSABLE
ORDER BY tiempo_total_reparacion DESC;

-- Vilca, Juarez, and Oscar are the technicians responsible for the highest total repair time. Let's check for recurring issues associated with them.

SELECT FECHA,
glosa,
responsable,
tiempo_reparacion,
personal_involucrado,
row_number() OVER(PARTITION BY glosa, responsable)
FROM mtt_camiones_copy
WHERE responsable = 'VILCA';

-- DATA QUALITY NOTE: It's observed that technician 'VILCA' has multiple task entries (GLOSA) on the same FECHA, despite varying equipment. 
-- This represents an inconsistency in the source data. For the scope of this analysis, this pattern is noted but not further processed. 
-- It is highly recommended to review the data capture process at the source to ensure future data integrity.

SELECT *,
row_number() OVER(PARTITION BY glosa, responsable)
FROM mtt_camiones_copy
WHERE responsable = 'VILCA';

-- The main changing variable is the specific equipment unit the operation was performed on, and other minor details.

-- Let's analyze the difference between the minimum and maximum work dates for each technician
	-- to determine if technicians with shorter work ranges were hired later.

SELECT responsable,
MIN(fecha),
MAX(fecha),
datediff(MAX(fecha),MIN(fecha)) AS rango_trabajo
FROM mtt_camiones_copy
GROUP BY responsable
ORDER BY rango_trabajo DESC;

-- Since several individuals performed work on the same day, we will label those who worked for less than 30 days as 'Temporary' personnel.

SELECT responsable,
MIN(fecha),
MAX(fecha),
datediff(MAX(fecha),MIN(fecha)) AS rango_trabajo,
CASE
WHEN datediff(MAX(fecha),MIN(fecha)) <= 30 THEN 'Temporary'
WHEN datediff(MAX(fecha),MIN(fecha)) > 30 THEN 'Permanent Staff'
		END as tipo_de_contrato
FROM mtt_camiones_copy
GROUP BY responsable
ORDER BY rango_trabajo DESC;


-- 4. Analyzing the Most Frequent Repair Types (GLOSA)

SELECT glosa,
COUNT(*) cuenta_rep,
sum(tiempo_reparacion) as total_tiempo_rep,
ROUND((sum(tiempo_reparacion)/(SELECT SUM(tiempo_reparacion) FROM mtt_camiones_copy))*100,2) as porcentaje_del_total
FROM mtt_camiones_copy
GROUP BY glosa
ORDER BY porcentaje_del_total DESC
LIMIT 10 ;

-- The main task observed, requiring the highest total repair time, is the installation of anchoring points.


-- 5. REPAIR TIME PERCENTAGE BY SYSTEM NAME

SELECT denominacion_sistema,
SUM(tiempo_reparacion) AS tiempo_rep_total,
ROUND(
	(SUM(tiempo_reparacion)/(
								SELECT SUM(tiempo_reparacion)
                                FROM mtt_camiones_copy)
                                )*100
	,2) as porcentaje_del_total
FROM mtt_camiones_copy
GROUP BY denominacion_sistema
ORDER BY porcentaje_del_total DESC;

-- 'CHASIS' and 'TOLVA' account for the highest percentage of total repair time by a significant margin. 

---- KEY FINDINGS AND RECOMMENDATIONS ----

-- The maintenance data analysis reveals critical points and areas for improvement in fleet management.

-- 1. Critical Maintenance Issues (Bottlenecks):

-- 'CHASIS' and 'TOLVA' systems account for the highest volume of failures and total repair time.
-- This suggests these systems are either design weak points or subject to the most severe operational conditions.
-- We recommend performing a specific Root Cause Analysis (RCA) to reduce critical failures in these systems.

-- 2. Seasonality and Capacity Planning:

-- A pattern of high maintenance demand was identified, concentrated in the last quarter of 2023 (peaking in October).
-- This seasonality should be factored into operational planning.
-- We recommend increasing maintenance staff capacity or critical spares inventory before this period to prevent operational delays.

-- 3. Efficiency and Labor Management:

-- The 'rango_trabajo' analysis reveals a significant reliance on "Temporary" personnel (working less than 30 days).
-- While the average manpower assigned to a repair is adequate, ensuring that high turnover does not impact the quality and consistency of complex repairs is crucial.

-- 4. Data Integrity Risk:

-- The data inconsistency detected in technician task logging (e.g., 'VILCA') highlights a weakness in source data quality.
-- Standardizing the logging protocols is urgently required to ensure that future information is accurate and reliable for decision-making.



