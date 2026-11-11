-- =============================================================================
-- SERCO ENTERPRISE DATA WAREHOUSE (EDW) - DDL SCHEMA & TABLE ARCHITECTURE
-- Platform: Microsoft SQL Server 2019+ / Azure SQL / Fabric SQL Endpoint
-- Architecture: Star Schema with Clustered Columnstore Fact Tables
-- Database: SercoAnalyticsDB
-- =============================================================================

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'SercoAnalyticsDB')
BEGIN
    CREATE DATABASE SercoAnalyticsDB;
END;
GO

USE SercoAnalyticsDB;
GO

-- -----------------------------------------------------------------------------
-- 1. Create Dedicated Schemas (Separation of Concerns)
-- -----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
    EXEC('CREATE SCHEMA stg AUTHORIZATION dbo;');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dim')
    EXEC('CREATE SCHEMA dim AUTHORIZATION dbo;');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'fact')
    EXEC('CREATE SCHEMA fact AUTHORIZATION dbo;');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'etl')
    EXEC('CREATE SCHEMA etl AUTHORIZATION dbo;');
GO

-- -----------------------------------------------------------------------------
-- 2. Drop Foreign Keys & Tables if Rebuilding
-- -----------------------------------------------------------------------------
IF OBJECT_ID('fact.PowerApps_Remediation_Audit', 'U') IS NOT NULL DROP TABLE fact.PowerApps_Remediation_Audit;
IF OBJECT_ID('fact.SLATickets', 'U') IS NOT NULL DROP TABLE fact.SLATickets;
IF OBJECT_ID('dim.Employees', 'U') IS NOT NULL DROP TABLE dim.Employees;
IF OBJECT_ID('dim.Channels', 'U') IS NOT NULL DROP TABLE dim.Channels;
IF OBJECT_ID('dim.Sites', 'U') IS NOT NULL DROP TABLE dim.Sites;
IF OBJECT_ID('dim.CostCenters', 'U') IS NOT NULL DROP TABLE dim.CostCenters;
IF OBJECT_ID('dim.Date', 'U') IS NOT NULL DROP TABLE dim.Date;
IF OBJECT_ID('etl.ExecutionLog', 'U') IS NOT NULL DROP TABLE etl.ExecutionLog;
GO

-- -----------------------------------------------------------------------------
-- 3. DIMENSION TABLES
-- -----------------------------------------------------------------------------

-- 3.1 Date Dimension (Supports Calendar & UK Fiscal Year)
CREATE TABLE dim.Date (
    [Date]               DATE NOT NULL,
    [Year]               INT NOT NULL,
    [Month]              TINYINT NOT NULL,
    [MonthName]          VARCHAR(15) NOT NULL,
    [MonthYear]          VARCHAR(10) NOT NULL,
    [Quarter]            CHAR(2) NOT NULL,
    [QuarterYear]        VARCHAR(10) NOT NULL,
    [WeekNumber]         TINYINT NOT NULL,
    [DayOfWeek]          VARCHAR(15) NOT NULL,
    [DayOfWeekNumber]    TINYINT NOT NULL,
    [IsWeekend]          BIT NOT NULL,
    [FiscalYear]         INT NOT NULL,
    [FiscalQuarter]      CHAR(6) NOT NULL,
    CONSTRAINT PK_dim_Date PRIMARY KEY CLUSTERED ([Date])
);
GO

-- 3.2 Cost Centers Dimension (Sectors, Operational Divisions & Budgets)
CREATE TABLE dim.CostCenters (
    Cost_Center_ID       VARCHAR(10) NOT NULL,
    Cost_Center_Name     VARCHAR(100) NOT NULL,
    Sector               VARCHAR(100) NOT NULL,
    Division             VARCHAR(100) NOT NULL,
    Cost_Center_Lead     VARCHAR(100) NOT NULL,
    Annual_Budget_GBP    DECIMAL(18, 2) NOT NULL DEFAULT 0.00,
    Created_At           DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dim_CostCenters PRIMARY KEY CLUSTERED (Cost_Center_ID)
);
GO

-- 3.3 Sites Dimension (Serco Global Facilities & Capacity Limits)
CREATE TABLE dim.Sites (
    Site_ID                  VARCHAR(10) NOT NULL,
    Site_Name                VARCHAR(100) NOT NULL,
    Region                   VARCHAR(50) NOT NULL,
    Country                  VARCHAR(50) NOT NULL,
    Capacity_Threshold_Daily INT NOT NULL DEFAULT 500,
    Created_At               DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dim_Sites PRIMARY KEY CLUSTERED (Site_ID)
);
GO

-- 3.4 Sourcing Channels Dimension (Talent Acquisition Benchmarks)
CREATE TABLE dim.Channels (
    Channel_ID                  VARCHAR(10) NOT NULL,
    Channel_Name                VARCHAR(100) NOT NULL,
    Channel_Category            VARCHAR(50) NOT NULL,
    Channel_Cost_Benchmark_GBP  DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    Retention_Benchmark_Pct     DECIMAL(5, 4) NOT NULL DEFAULT 0.8500,
    Created_At                  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dim_Channels PRIMARY KEY CLUSTERED (Channel_ID)
);
GO

-- 3.5 Employees Dimension (Workforce Demographics, EDI & Hierarchy)
CREATE TABLE dim.Employees (
    Employee_ID          VARCHAR(15) NOT NULL,
    Employee_Name        VARCHAR(100) NOT NULL,
    Gender               VARCHAR(20) NOT NULL,
    Ethnicity            VARCHAR(50) NOT NULL,
    Veteran_Status       VARCHAR(50) NOT NULL DEFAULT 'Non-Forces',
    Disability_Status    VARCHAR(50) NOT NULL DEFAULT 'No Declared Disability',
    Hierarchy_Tier       VARCHAR(50) NOT NULL,
    [Role]               VARCHAR(50) NOT NULL,
    Site_ID              VARCHAR(10) NOT NULL,
    Cost_Center_ID       VARCHAR(10) NOT NULL,
    Channel_ID           VARCHAR(10) NOT NULL,
    Hourly_Rate_GBP      DECIMAL(10, 2) NOT NULL DEFAULT 20.00,
    Tenure_Years         TINYINT NOT NULL DEFAULT 1,
    IsActive             BIT NOT NULL DEFAULT 1,
    ValidFrom            DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ValidTo              DATETIME2 NULL,
    CONSTRAINT PK_dim_Employees PRIMARY KEY CLUSTERED (Employee_ID),
    CONSTRAINT FK_dim_Employees_Site FOREIGN KEY (Site_ID) REFERENCES dim.Sites(Site_ID),
    CONSTRAINT FK_dim_Employees_CostCenter FOREIGN KEY (Cost_Center_ID) REFERENCES dim.CostCenters(Cost_Center_ID),
    CONSTRAINT FK_dim_Employees_Channel FOREIGN KEY (Channel_ID) REFERENCES dim.Channels(Channel_ID)
);
GO

-- -----------------------------------------------------------------------------
-- 4. FACT TABLES
-- -----------------------------------------------------------------------------

-- 4.1 SLA Tickets Fact (Core Operational Telemetry - 30k+ records)
CREATE TABLE fact.SLATickets (
    Ticket_ID               VARCHAR(20) NOT NULL,
    Created_Timestamp       DATETIME2 NOT NULL,
    Created_Date            DATE NOT NULL,
    Cost_Center_ID          VARCHAR(10) NOT NULL,
    Sector                  VARCHAR(100) NOT NULL,
    Contract_Type           VARCHAR(50) NOT NULL,
    [Priority]              VARCHAR(20) NOT NULL,
    Site_ID                 VARCHAR(10) NOT NULL,
    Assigned_Employee_ID    VARCHAR(15) NOT NULL,
    Channel_ID              VARCHAR(10) NOT NULL,
    SLA_Target_Hours        INT NOT NULL,
    Actual_Resolution_Hours DECIMAL(10, 2) NOT NULL,
    SLA_Status              VARCHAR(20) NOT NULL,
    Operational_Cost_GBP    DECIMAL(12, 2) NOT NULL,
    Penalty_Cost_GBP        DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    CSAT_Score              TINYINT NOT NULL,
    Ingested_At             DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_fact_SLATickets PRIMARY KEY NONCLUSTERED (Ticket_ID),
    CONSTRAINT FK_fact_SLATickets_Date FOREIGN KEY (Created_Date) REFERENCES dim.Date([Date]),
    CONSTRAINT FK_fact_SLATickets_CostCenter FOREIGN KEY (Cost_Center_ID) REFERENCES dim.CostCenters(Cost_Center_ID),
    CONSTRAINT FK_fact_SLATickets_Site FOREIGN KEY (Site_ID) REFERENCES dim.Sites(Site_ID),
    CONSTRAINT FK_fact_SLATickets_Employee FOREIGN KEY (Assigned_Employee_ID) REFERENCES dim.Employees(Employee_ID),
    CONSTRAINT FK_fact_SLATickets_Channel FOREIGN KEY (Channel_ID) REFERENCES dim.Channels(Channel_ID),
    CONSTRAINT CK_SLATickets_CSAT CHECK (CSAT_Score BETWEEN 1 AND 5),
    CONSTRAINT CK_SLATickets_Status CHECK (SLA_Status IN ('Resolved On-Time', 'SLA Breached'))
);
GO

-- Clustered Columnstore Index for high-speed analytical aggregation
CREATE CLUSTERED COLUMNSTORE INDEX CCI_fact_SLATickets ON fact.SLATickets;
GO

-- Secondary B-tree index for high-cardinality point lookups
CREATE NONCLUSTERED INDEX IX_fact_SLATickets_Filter 
ON fact.SLATickets (Created_Date, Sector, Assigned_Employee_ID)
INCLUDE (Operational_Cost_GBP, Penalty_Cost_GBP, SLA_Status, CSAT_Score);
GO

-- 4.2 PowerApps Remediation Audit Fact (Dataverse / Closed-Loop Governance)
CREATE TABLE fact.PowerApps_Remediation_Audit (
    Audit_ID                    VARCHAR(20) NOT NULL,
    Ticket_ID                   VARCHAR(20) NOT NULL,
    Remediated_By_Employee_ID   VARCHAR(15) NOT NULL,
    Remediation_Action          VARCHAR(100) NOT NULL,
    Action_Timestamp            DATETIME2 NOT NULL,
    Action_Date                 DATE NOT NULL,
    PowerAutomate_Triggered     BIT NOT NULL DEFAULT 1,
    Logged_At                   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_fact_PowerApps_Audit PRIMARY KEY CLUSTERED (Audit_ID),
    CONSTRAINT FK_fact_Audit_Ticket FOREIGN KEY (Ticket_ID) REFERENCES fact.SLATickets(Ticket_ID),
    CONSTRAINT FK_fact_Audit_Employee FOREIGN KEY (Remediated_By_Employee_ID) REFERENCES dim.Employees(Employee_ID),
    CONSTRAINT FK_fact_Audit_Date FOREIGN KEY (Action_Date) REFERENCES dim.Date([Date])
);
GO

-- -----------------------------------------------------------------------------
-- 5. ETL PIPELINE EXECUTION LOGGING TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE etl.ExecutionLog (
    Log_ID          BIGINT IDENTITY(1,1) NOT NULL,
    Pipeline_Name   VARCHAR(100) NOT NULL,
    Source_System   VARCHAR(50) NOT NULL,
    Rows_Ingested   INT NULL,
    Rows_Rejected   INT NULL,
    Status          VARCHAR(20) NOT NULL,
    Error_Message   NVARCHAR(MAX) NULL,
    Start_Time      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    End_Time        DATETIME2 NULL,
    CONSTRAINT PK_etl_ExecutionLog PRIMARY KEY CLUSTERED (Log_ID)
);
GO

PRINT 'Serco EDW Schemas, Tables and Clustered Columnstore Indexes successfully created.';
GO
