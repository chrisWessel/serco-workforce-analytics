-- ==============================================================================
-- SERCO GLOBAL TALENT & WORKFORCE ANALYTICS PLATFORM
-- Script: 03_executive_analytics_queries.sql
-- Description: Advanced analytical SQL queries designed for hiring managers and
--              executive leadership. Demonstrates complex CTEs, Window Functions,
--              SLA penalty models, statistical quartiles, and EDI metrics.
-- RDBMS: Microsoft SQL Server / Azure SQL Database
-- Author: Enterprise Data Engineering & BI Architecture Team
-- ==============================================================================

USE [SercoAnalytics];
GO

-- ==============================================================================
-- QUERY 1: CONTRACTUAL SLA BREACH & FINANCIAL PENALTY EXPOSURE BY SECTOR
-- Business Context: Identifies crown commercial contract exposure, total breach
-- volume, and ranked financial risk per sector and ticket priority.
-- Concepts: CTEs, Conditional Aggregations, DENSE_RANK(), Formatted Currency.
-- ==============================================================================
WITH SectorBreachMetrics AS (
    SELECT 
        f.Sector,
        f.Priority,
        COUNT(f.Ticket_SK) AS Total_Tickets,
        SUM(CAST(f.Is_Breached AS INT)) AS Breached_Tickets,
        ROUND(AVG(f.Resolution_Time_Hours), 1) AS Avg_Resolution_Hours,
        ROUND(AVG(f.Target_SLA_Hours), 1) AS Target_SLA_Hours,
        SUM(f.Penalty_Cost_GBP) AS Total_Penalty_Exposure_GBP,
        CAST(ROUND(SUM(CAST(f.Is_Breached AS FLOAT)) / COUNT(f.Ticket_SK) * 100, 2) AS DECIMAL(5,2)) AS Breach_Rate_Pct
    FROM fact.SLATickets f
    GROUP BY f.Sector, f.Priority
)
SELECT 
    Sector,
    Priority,
    Total_Tickets,
    Breached_Tickets,
    Breach_Rate_Pct,
    Avg_Resolution_Hours,
    Target_SLA_Hours,
    FORMAT(Total_Penalty_Exposure_GBP, 'C', 'en-GB') AS Formatted_Penalty_GBP,
    DENSE_RANK() OVER (ORDER BY Total_Penalty_Exposure_GBP DESC) AS Financial_Risk_Rank,
    CASE 
        WHEN Breach_Rate_Pct > 20.0 THEN 'CRITICAL RISK - CROWN AUDIT TRIGGER'
        WHEN Breach_Rate_Pct BETWEEN 10.0 AND 20.0 THEN 'ELEVATED RISK - INTERVENTION REQ'
        ELSE 'WITHIN CONTRACTUAL TOLERANCE'
    END AS Contractual_Governance_Status
FROM SectorBreachMetrics
ORDER BY Total_Penalty_Exposure_GBP DESC, Breach_Rate_Pct DESC;
GO

-- ==============================================================================
-- QUERY 2: ROLLING 30-DAY INCIDENT VOLUME & MOVING AVERAGE DEFICIT TRAJECTORY
-- Business Context: Smoothes daily volatility to assess whether operational load
-- is spiking faster than workforce capacity can absorb.
-- Concepts: Multi-frame Window Functions (ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),
--           LAG() to compute day-over-day acceleration.
-- ==============================================================================
WITH DailyIncidentRollup AS (
    SELECT 
        CAST(f.Created_Date AS DATE) AS Incident_Date,
        COUNT(f.Ticket_SK) AS Daily_Ticket_Volume,
        SUM(CAST(f.Is_Breached AS INT)) AS Daily_Breaches,
        ROUND(AVG(f.Resolution_Time_Hours), 2) AS Daily_Avg_Resolution_Hours
    FROM fact.SLATickets f
    GROUP BY CAST(f.Created_Date AS DATE)
)
SELECT 
    Incident_Date,
    Daily_Ticket_Volume,
    Daily_Breaches,
    Daily_Avg_Resolution_Hours,
    -- 30-Day Moving Average of Ingested Incident Volume
    ROUND(AVG(Daily_Ticket_Volume) OVER (
        ORDER BY Incident_Date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 1) AS Rolling_30Day_Avg_Volume,
    -- 30-Day Moving Average of SLA Breaches
    ROUND(AVG(Daily_Breaches) OVER (
        ORDER BY Incident_Date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 1) AS Rolling_30Day_Avg_Breaches,
    -- Day-over-Day Velocity Spike %
    ROUND(
        (Daily_Ticket_Volume - LAG(Daily_Ticket_Volume, 1, Daily_Ticket_Volume) OVER (ORDER BY Incident_Date))
        * 100.0 / NULLIF(LAG(Daily_Ticket_Volume, 1, Daily_Ticket_Volume) OVER (ORDER BY Incident_Date), 0),
        2
    ) AS DoD_Volume_Growth_Pct
FROM DailyIncidentRollup
ORDER BY Incident_Date DESC;
GO

-- ==============================================================================
-- QUERY 3: TALENT SOURCING CHANNEL EFFICIENCY & IN-HOUSE RECRUITMENT ROI
-- Business Context: Compares recruitment costs across sourcing channels versus
-- third-party commercial staffing agencies to quantify in-house cost avoidance.
-- Concepts: Sourcing Channel Economics, Cost Avoidance Variance, 90-Day Retention.
-- ==============================================================================
WITH ChannelEconomics AS (
    SELECT 
        c.Channel_Name,
        c.Channel_Type,
        c.Benchmark_Cost_Per_Hire_GBP,
        c.Avg_90Day_Retention_Pct,
        COUNT(f.Ticket_SK) AS Active_Operational_Hires,
        -- Agency standard baseline cost: £7,500 per placement
        COUNT(f.Ticket_SK) * 7500.00 AS Agency_Baseline_Cost_GBP,
        COUNT(f.Ticket_SK) * c.Benchmark_Cost_Per_Hire_GBP AS Actual_Channel_Cost_GBP
    FROM dim.Channels c
    LEFT JOIN fact.SLATickets f 
        ON c.Channel_Name = f.Channel
    GROUP BY 
        c.Channel_Name, 
        c.Channel_Type, 
        c.Benchmark_Cost_Per_Hire_GBP, 
        c.Avg_90Day_Retention_Pct
)
SELECT 
    Channel_Name,
    Channel_Type,
    Active_Operational_Hires,
    FORMAT(Benchmark_Cost_Per_Hire_GBP, 'C', 'en-GB') AS Unit_Cost_Per_Hire,
    CONCAT(Avg_90Day_Retention_Pct, '%') AS Benchmark_Retention_90Day,
    FORMAT(Actual_Channel_Cost_GBP, 'C', 'en-GB') AS Total_Actual_Spend_GBP,
    FORMAT(Agency_Baseline_Cost_GBP - Actual_Channel_Cost_GBP, 'C', 'en-GB') AS Net_Cost_Avoidance_GBP,
    ROUND((Agency_Baseline_Cost_GBP - Actual_Channel_Cost_GBP) / NULLIF(Agency_Baseline_Cost_GBP, 0) * 100, 1) AS Sourcing_Efficiency_Savings_Pct
FROM ChannelEconomics
ORDER BY (Agency_Baseline_Cost_GBP - Actual_Channel_Cost_GBP) DESC;
GO

-- ==============================================================================
-- QUERY 4: RECRUITER PERFORMANCE QUARTILES & TIME-TO-FILL / SLA VELOCITY
-- Business Context: Benchmarks recruiter productivity into performance quartiles
-- to identify coaching candidates vs top performers.
-- Concepts: NTILE(4), PERCENT_RANK(), Window Partitioning.
-- ==============================================================================
WITH RecruiterAggregates AS (
    SELECT 
        COALESCE(c.Lead_Recruiter, 'Unassigned') AS Lead_Recruiter,
        c.Sector,
        COUNT(f.Ticket_SK) AS Requisitions_Handled,
        SUM(CAST(f.Is_Breached AS INT)) AS Total_SLA_Breaches,
        ROUND(AVG(f.Resolution_Time_Hours), 1) AS Avg_Turnaround_Hours,
        ROUND(SUM(CAST(f.Is_Breached AS FLOAT)) / COUNT(f.Ticket_SK) * 100, 1) AS Breach_Percentage
    FROM fact.SLATickets f
    INNER JOIN dim.CostCenters c 
        ON f.Cost_Center_Code = c.Cost_Center_Code
    GROUP BY c.Lead_Recruiter, c.Sector
)
SELECT 
    Lead_Recruiter,
    Sector,
    Requisitions_Handled,
    Total_SLA_Breaches,
    Avg_Turnaround_Hours,
    Breach_Percentage,
    NTILE(4) OVER (ORDER BY Avg_Turnaround_Hours ASC) AS Velocity_Quartile, -- Q1 = Fastest turnaround
    ROUND(PERCENT_RANK() OVER (ORDER BY Requisitions_Handled DESC) * 100, 1) AS Volume_Percentile_Rank,
    CASE 
        WHEN NTILE(4) OVER (ORDER BY Avg_Turnaround_Hours ASC) = 1 THEN 'Top Performer (Tier 1)'
        WHEN NTILE(4) OVER (ORDER BY Avg_Turnaround_Hours ASC) = 2 THEN 'Above Average (Tier 2)'
        WHEN NTILE(4) OVER (ORDER BY Avg_Turnaround_Hours ASC) = 3 THEN 'Standard Delivery (Tier 3)'
        ELSE 'Capacity / Performance Coaching Required'
    END AS Performance_Classification
FROM RecruiterAggregates
ORDER BY Avg_Turnaround_Hours ASC;
GO

-- ==============================================================================
-- QUERY 5: VERTICAL EDI PIPELINE PROGRESSION & GLASS CEILING ANALYSIS
-- Business Context: Tracks female and underrepresented minority representation
-- across 5 organizational tiers from Frontline to Executive Directorate.
-- Demonstrates progress toward the Serco 40% Female Leadership Target.
-- Concepts: Conditional aggregation, ratio analysis, vertical equity gaps.
-- ==============================================================================
WITH TierEDIAnalysis AS (
    SELECT 
        e.Tier_Hierarchy,
        COUNT(e.Employee_SK) AS Total_Headcount,
        SUM(CASE WHEN e.Gender = 'Female' THEN 1 ELSE 0 END) AS Female_Count,
        SUM(CASE WHEN e.Gender = 'Male' THEN 1 ELSE 0 END) AS Male_Count,
        SUM(CASE WHEN e.Ethnicity NOT IN ('White - British', 'White - Other') THEN 1 ELSE 0 END) AS Diverse_Ethnic_Count,
        SUM(CAST(e.Is_Veteran AS INT)) AS Veteran_Count,
        SUM(CAST(e.Is_Apprentice AS INT)) AS Social_Mobility_Apprentices
    FROM dim.Employees e
    WHERE e.Is_Current = 1
    GROUP BY e.Tier_Hierarchy
)
SELECT 
    Tier_Hierarchy,
    Total_Headcount,
    Female_Count,
    CAST(ROUND(Female_Count * 100.0 / NULLIF(Total_Headcount, 0), 1) AS DECIMAL(5,1)) AS Female_Representation_Pct,
    Diverse_Ethnic_Count,
    CAST(ROUND(Diverse_Ethnic_Count * 100.0 / NULLIF(Total_Headcount, 0), 1) AS DECIMAL(5,1)) AS Ethnic_Diversity_Pct,
    Veteran_Count,
    Social_Mobility_Apprentices,
    CASE 
        WHEN (Female_Count * 100.0 / NULLIF(Total_Headcount, 0)) >= 40.0 THEN 'ACHIEVED: Meets 40% Executive Target'
        ELSE CONCAT('DEFICIT: Need +', CEILING((0.40 * Total_Headcount) - Female_Count), ' Female Leaders to Meet Parity')
    END AS Parity_Target_Assessment
FROM TierEDIAnalysis
ORDER BY Tier_Hierarchy ASC;
GO

-- ==============================================================================
-- QUERY 6: CLOSED-LOOP POWER APPS REMEDIATION YIELD VS MANUAL RESOLUTION
-- Business Context: Evaluates the impact of Power Automate / Power Apps workflows
-- on reducing Mean Time to Resolution (MTTR) and avoiding SLA breaches.
-- Concepts: Comparative A/B Grouping, Cost-Saving Estimation.
-- ==============================================================================
SELECT 
    f.Sector,
    COUNT(f.Ticket_SK) AS Total_Tickets,
    -- Automation Group Metrics
    SUM(CASE WHEN f.PowerApps_Remediated = 1 THEN 1 ELSE 0 END) AS Automated_Tickets,
    ROUND(AVG(CASE WHEN f.PowerApps_Remediated = 1 THEN f.Resolution_Time_Hours END), 1) AS Automated_Avg_MTTR_Hours,
    ROUND(SUM(CASE WHEN f.PowerApps_Remediated = 1 THEN CAST(f.Is_Breached AS FLOAT) ELSE 0 END) 
          / NULLIF(SUM(CASE WHEN f.PowerApps_Remediated = 1 THEN 1 ELSE 0 END), 0) * 100, 1) AS Automated_Breach_Rate_Pct,
    -- Manual Resolution Group Metrics
    SUM(CASE WHEN f.PowerApps_Remediated = 0 THEN 1 ELSE 0 END) AS Manual_Tickets,
    ROUND(AVG(CASE WHEN f.PowerApps_Remediated = 0 THEN f.Resolution_Time_Hours END), 1) AS Manual_Avg_MTTR_Hours,
    ROUND(SUM(CASE WHEN f.PowerApps_Remediated = 0 THEN CAST(f.Is_Breached AS FLOAT) ELSE 0 END) 
          / NULLIF(SUM(CASE WHEN f.PowerApps_Remediated = 0 THEN 1 ELSE 0 END), 0) * 100, 1) AS Manual_Breach_Rate_Pct,
    -- Efficiency Gain (Hours Saved per Ticket)
    ROUND(
        AVG(CASE WHEN f.PowerApps_Remediated = 0 THEN f.Resolution_Time_Hours END) -
        AVG(CASE WHEN f.PowerApps_Remediated = 1 THEN f.Resolution_Time_Hours END),
        1
    ) AS MTTR_Hours_Saved_By_Automation
FROM fact.SLATickets f
GROUP BY f.Sector
ORDER BY MTTR_Hours_Saved_By_Automation DESC;
GO
