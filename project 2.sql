
rename table  hr_attrition to hr_employees;
-- HR Analytics: corrected SQL script (MySQL 8.0+)
-- Table: hr_employees (1470 rows)
-- =====================================================
 
-- One-time setup (already done, keep commented so the file can be re-run safely):
-- create database HR_Analytics;
-- alter table project_2_11 rename to hr_employees;
-- NEVER keep "drop table hr_employees;" in this file.
 
use HR_Analytics;
 
 
-- 1. Display the first 10 rows from the table.
select *
from hr_employees
limit 10;
 
 
-- 2. Find the total number of employees in the company.
select count(EmployeeNumber) as total_employees
from hr_employees;
-- Check: 1470
 
 
-- 3. List all unique departments.
select distinct Department
from hr_employees;
 
 
-- 4. Show how many employees have left the company and how many are still working.
select sum(case when Attrition = 'Yes' then 1 else 0 end) as employees_left,
       sum(case when Attrition = 'No'  then 1 else 0 end) as employees_working
from hr_employees;
-- Check: left + working = 1470 (left = 237, working = 1233)
 
 
-- 5. Retrieve the list of employees who work overtime.
select *
from hr_employees
where OverTime = 'Yes';
 
 
-- 6. Find the average monthly income of all employees.
select round(avg(MonthlyIncome), 2) as average_monthly_income
from hr_employees;
 
 
-- 7. Identify employees whose number of companies worked is missing (NULL).
select *
from hr_employees
where NumCompaniesWorked is null;
-- 0 rows is a valid answer if the column has no NULLs
 
 
-- 8. Find the employee(s) with the maximum monthly income.
select *
from hr_employees
where MonthlyIncome = (select max(MonthlyIncome) from hr_employees);
 
 
-- 9. Count the number of employees by gender.
select Gender,
       count(*) as count_of_gender
from hr_employees
group by Gender;
 
 
-- 10. List all employees who have just joined (YearsAtCompany = 0).
select *
from hr_employees
where YearsAtCompany = 0;
 
 
-- 11. Calculate the attrition rate (%) by department.
select Department,
       count(*) as total_employees,
       sum(case when Attrition = 'Yes' then 1 else 0 end) as employees_left,
       round(sum(case when Attrition = 'Yes' then 1 else 0 end) * 100.0 / count(*), 2) as attrition_rate_percent
from hr_employees
group by Department;
-- Check: employees_left adds up to 237
 
 
-- 12. List the top 10 employees with the highest total working years.
select *
from hr_employees
order by TotalWorkingYears desc, EmployeeNumber
limit 10;
 
 
-- 13. Group employees into tenure categories (<1yr, 1-3yr, 4-6yr, 7+yr) and count employees in each.
select case when YearsAtCompany < 1  then '<1 yr'
            when YearsAtCompany <= 3 then '1-3 yr'
            when YearsAtCompany <= 6 then '4-6 yr'
            else '7+ yr'
       end as tenure_category,
       count(*) as employees
from hr_employees
group by tenure_category
order by min(YearsAtCompany);
-- Check: the four counts add up to 1470
 
 
-- 14. Find the average monthly income by job level and attrition status.
select JobLevel,
       Attrition,
       round(avg(MonthlyIncome), 2) as avg_monthly_income
from hr_employees
group by JobLevel, Attrition
order by JobLevel, Attrition;
 
 
-- 15. Identify the top 5 job roles with the highest number of employees who left.
select JobRole,
       count(*) as employees_left
from hr_employees
where Attrition = 'Yes'
group by JobRole
order by employees_left desc
limit 5;
 
 
-- 16. List employees who left the company within their first year.
select EmployeeNumber, Department, JobRole, YearsAtCompany
from hr_employees
where Attrition = 'Yes'
  and YearsAtCompany < 1;
 
 
-- 17. Calculate each employee's approximate new monthly compensation after applying
--     their salary hike percentage.
select EmployeeNumber,
       Department,
       MonthlyIncome as current_monthly_salary,
       PercentSalaryHike as hike_percentage,
       round(MonthlyIncome * (1 + PercentSalaryHike / 100.0), 2) as new_monthly_compensation
from hr_employees;
 
 
-- 18. Count employees grouped by overtime status and attrition.
select OverTime,
       Attrition,
       count(*) as employees
from hr_employees
group by OverTime, Attrition
order by OverTime, Attrition;
 
-- 18 (bonus). Attrition rate inside each overtime group.
select OverTime,
       count(*) as total_employees,
       round(sum(case when Attrition = 'Yes' then 1 else 0 end) * 100.0 / count(*), 2) as attrition_pct
from hr_employees
group by OverTime;
 
 
-- 19. Display the top 10 employees who attended the most training sessions last year.
select *
from hr_employees
order by TrainingTimesLastYear desc, EmployeeNumber
limit 10;
 
 
-- 20. Rank employees by total working years (most experienced = rank 1).
select EmployeeNumber,
       TotalWorkingYears,
       dense_rank() over (order by TotalWorkingYears desc) as experience_rank
from hr_employees
order by experience_rank, EmployeeNumber;
 
 
-- 21. For each department, find employees whose monthly income is in the top 25% of that department.
select EmployeeNumber, Department, MonthlyIncome
from (
    select EmployeeNumber,
           Department,
           MonthlyIncome,
           percent_rank() over (partition by Department order by MonthlyIncome) as income_rank
    from hr_employees
) as ranked_data
where income_rank >= 0.75
order by Department, MonthlyIncome desc;
 
 
-- 22. Divide employees into 10 income deciles and find the attrition rate for each decile.
with decile_table as (
    select MonthlyIncome,
           Attrition,
           ntile(10) over (order by MonthlyIncome) as income_decile
    from hr_employees
)
select income_decile as decile,
       min(MonthlyIncome) as min_income,
       max(MonthlyIncome) as max_income,
       count(*) as total_employees,
       round(sum(case when Attrition = 'Yes' then 1 else 0 end) * 100.0 / count(*), 2) as attrition_rate_percent
from decile_table
group by income_decile
order by income_decile;
 
 
-- 23. Create a simple risk score based on tenure, performance, overtime and work-life balance,
--     and list the top 50 high-risk employees (only employees still in the company).
-- Before running, check the rating values: select distinct PerformanceRating from hr_employees;
-- If the values are only 3 and 4, the "rating <= 2" rule below never adds points.
with risk_calculation as (
    select EmployeeNumber,
           YearsAtCompany,
           PerformanceRating,
           OverTime,
           WorkLifeBalance,
           (
               -- 1. Overtime risk
               case when OverTime = 'Yes' then 3 else 0 end
               -- 2. Work-life balance risk (1 = worst -> 3 points ... 4 = best -> 0 points)
             + case when WorkLifeBalance = 1 then 3
                    when WorkLifeBalance = 2 then 2
                    when WorkLifeBalance = 3 then 1
                    else 0 end
               -- 3. Tenure risk (newer employees are more likely to leave)
             + case when YearsAtCompany <= 2 then 2
                    when YearsAtCompany <= 5 then 1
                    else 0 end
               -- 4. Performance risk (low rating)
             + case when PerformanceRating <= 2 then 2 else 0 end
           ) as risk_score
    from hr_employees
    where Attrition = 'No'
)
select EmployeeNumber,
       YearsAtCompany as tenure,
       OverTime,
       WorkLifeBalance,
       PerformanceRating,
       risk_score
from risk_calculation
order by risk_score desc, YearsAtCompany, EmployeeNumber
limit 50;
 
 
-- 24. Summary view for each department and job level:
--     total employees, leavers, attrition rate and average monthly income.
create or replace view dept_joblevel_summary as
select Department,
       JobLevel,
       count(*) as total_employees,
       sum(case when Attrition = 'Yes' then 1 else 0 end) as leavers,
       round(sum(case when Attrition = 'Yes' then 1 else 0 end) * 100.0 / count(*), 2) as attrition_rate,
       round(avg(MonthlyIncome), 2) as avg_monthly_income
from hr_employees
group by Department, JobLevel;
 
 select * from hr_employees;
select * 
from dept_joblevel_summary
order by attrition_rate desc;
-- Check: sum(total_employees) = 1470 and sum(leavers) = 237
select sum(total_employees) as total_employees, sum(leavers) as total_leavers
from dept_joblevel_summary;
 
