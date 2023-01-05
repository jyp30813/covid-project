-- We investigate the covid-19 pandemic in the shoes of a hospital in Singapore, 
-- analyzing bottlenecks of hospitals and the degree to which they were strained.


-- Beginning from querying certain data from the dataset. 
-- Possible bottlenecks: hospital bed occupancy, mortuary occupancy
-- Questions:
	-- 1. What were the ICU Bed occupancy rates due to covid-19?
	-- 2. Which countries experienced high influx of hospitalized patients(>9%)? 
	-- 3. Which countries have similar demographics, policies, and standard of living to Singapore?


-- 1. What were the ICU Bed occupancy rates due to covid-19?
	-- Create temp table ICUBedOcc, find the bed occupancy rate by dividing hospitalization rate (icu patients + hospitalized patients)
	-- by total hospital beds in the country.

drop table if exists ICUBedOcc;
create temp table ICUBedOcc
(
	location text,
	date date,
	icu_patients bigint,
	hosp_patients bigint,
	hospital_beds int,
	Bed_Occupancy double precision
)
;

insert into ICUBedOcc
select b.location, b.date, b.icu_patients, b.hosp_patients, b.hospital_beds, (b.icu_patients+hosp_patients)/b.hospital_beds as Bed_Occupancy
from (
	select location, date, icu_patients, hosp_patients, hospital_beds_per_thousand*population/1000 as hospital_beds
	from covid_data
	where continent is not null and icu_patients is not null
	order by location, date
)as b
where hospital_beds is not null;


-- 2. Which countries experienced high influx of hospitalized patients(>9%)? 
	-- Create view with maximum bed occupancy rates due to covid-19. View to be visualized in Tableau.
	
drop view if exists MaxBedOcc;
create view MaxBedOcc as
select location, MAX(Bed_Occupancy) as MaxBedOccupancy
from ICUBedOcc
where Bed_Occupancy > 0.09
group by location;

drop view if exists BedOccDates;
create view BedOccDates as
select location, Bed_Occupancy, date
from ICUBedOcc
where Bed_Occupancy > 0.09;

select distinct mbo.location, mbo.MaxBedOccupancy, date
from MaxBedOcc as mbo
left join BedOccDates as bod
on mbo.location = bod.location and mbo.MaxBedOccupancy = bod.Bed_Occupancy


-- 3. Which countries have similar demographics, policies, and standard of living to Singapore?
	-- Resulting view will be further analyzed in Python with Pandas.
	-- Pandas k-meams clustering will be used, with parameters: stringency index (policy strictness in containing the coronavirus),
	-- population density, elderly population, gdp per capita, and human development index.

	-- NOTE: to use clustering, data had to be normalized, and for simplicity have the same number of rows.
	-- Some countries lacked data on certain dates, therefore three datasets were extracted to negate the date variable: average, maximum, and minimum of all variables
drop view if exists Similarity_data;
create view Similarity_data as
select location, date,
case 
	when stringency_index is null then 0
	else stringency_index
end,
case 
	when population_density is null then 0
	else population_density
end, 
case 
	when aged_65_older is null then 0
	else aged_65_older
end as aged_65_older_percent,
case 
	when gdp_per_capita is null then 0
	else gdp_per_capita
end,
case 
	when human_development_index is null then 0
	else human_development_index
end
from covid_data
where continent is not null
order by location, date;


drop view if exists avg_similarity_data;
create view avg_similarity_data as
select location, avg(stringency_index) as avg_stringency_index, avg(population_density) as avg_population_density,
	avg(aged_65_older_percent) as avg_aged_65_older_percent,avg(gdp_per_capita) as avg_gdp_per_capita,
	avg(human_development_index) as avg_human_development_index
from Similarity_data
group by location;


drop view if exists min_similarity_data;
create view min_similarity_data as
select location as b_location, min(stringency_index) as min_stringency_index, min(population_density) as min_population_density,
	min(aged_65_older_percent) as min_aged_65_older_percent,min(gdp_per_capita) as min_gdp_per_capita,
	min(human_development_index) as min_human_development_index
from Similarity_data
group by location;


drop view if exists max_similarity_data;
create view max_similarity_data as
select location as c_location, max(stringency_index) as max_stringency_index, max(population_density) as max_population_density,
	max(aged_65_older_percent) as max_aged_65_older_percent,max(gdp_per_capita) as max_gdp_per_capita,
	max(human_development_index) as max_human_development_index
from Similarity_data
group by location;

drop view if exists join_similarity_data;
create view join_similarity_data as
select * 
from avg_similarity_data as avg
join min_similarity_data as min on avg.location = min.b_location
join max_similarity_data as max on avg.location = max.c_location;



-- 4. How long did it take countries like Singapore to reach critical points in capacity? how long until returning to acceptable levels?
	-- This step is done after the clustering in Pandas is complete. 
	-- Queried data will be visualized in Tableau to indicate how often hospitals in countries like Singapore experienced
	-- stringency in hospital occupation rates and how long it took them to return to normal levels. 

select location, Bed_Occupancy, date
from ICUBedOcc
where Bed_Occupancy > 0.09 and
	(location = 'Hong Kong' or location = 'Luxembourg' or location = 'Qatar' or location = 'Singapore')
order by location, date asc
-- Luxemburg 11/16 to 11/26 (11 days), and 12/09 to 12/17 (9 days)
select location, Bed_Occupancy, date
from ICUBedOcc
where location = 'Hong Kong' or location = 'Luxembourg' or location = 'Qatar' or location = 'Singapore'
order by location, date asc


-- 5. Mortuary Occupancy

-- during the height of the pandemic, hospital mortuaries were at full capacity as well. excess mortality would be important to consider for hopsitals with regularly high occupancy rates
-- recorded last day of every month, compared to same periods of previous years
select location, date, excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute, excess_mortality_cumulative_per_million
from covid_data
where excess_mortality > 20 and 
	(location = 'Hong Kong' or location = 'Luxembourg' or location = 'Qatar' or location = 'Singapore')
order by location, date asc;

select location, date, excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute, excess_mortality_cumulative_per_million
from covid_data
where excess_mortality is not null and 
	(location = 'Hong Kong' or location = 'Luxembourg' or location = 'Qatar' or location = 'Singapore')
order by location, date asc
