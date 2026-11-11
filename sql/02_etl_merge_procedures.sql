-- ==============================================================================
-- SERCO GLOBAL TALENT & WORKFORCE ANALYTICS PLATFORM
-- Script: 02_etl_merge_procedures.sql
-- Description: Production-grade ETL Stored Procedures implementing Idempotent
--              MERGE upserts, SCD Type 2 tracking, and execution logging.
-- RDBMS: Microsoft SQL Server 2019 / 2022 / Azure SQL Database
-- Author: Enterprise Data Engineering & BI Architecture Team
-- ==============================================================================

USE [SercoAnalytics];
GO

-- ==============================================================================
-- 1. PROCEDURE: etl.sp_Load_Fact_SLATickets
-- Description: Idempotent MERGE upsert from staging to fact.SLATickets.
--              Calculates contractual SLA breach flags, assigns surrogate keys,
--              and records execution metrics in etl.ExecutionLog.
-- ==============================================================================
CREATE OR ALTER PROCEDURE etl.sp_Load_Fact_SLATickets
    @BatchID NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartTime DATETIME2 = SYSDATETIME();
    DECLARE @ProcedureName NVARCHAR(100) = OBJECT_NAME(@@PROCID);
    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsUpdated INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);

    IF @BatchID IS NULL
        SET @BatchID = CONCAT('BATCH_', FORMAT(GETDATE(), 'yyyyMMdd_HHmmss'));

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Create a temporary table to capture MERGE output actions
        CREATE TABLE #MergeActions (
            ActionTaken NVARCHAR(10)
        );

        -- Execute Idempotent MERGE
        MERGE INTO fact.SLATickets AS target
        USING (
            SELECT 
                s.Ticket_ID,
                s.Created_Date,
                s.Resolved_Date,
                s.Priority,
                s.Status,
                s.Sector,
                s.Role,
                s.Cost_Center_Code,
                s.Site_Code,
                s.Employee_ID,
                s.Channel,
                s.Contract_Type,
                s.Resolution_Time_Hours,
                s.Target_SLA_Hours,
                -- Calculated SLA breach: if resolution exceeds target or ticket unresolved past target
                CASE 
                    WHEN s.Resolution_Time_Hours > s.Target_SLA_Hours THEN 1
                    WHEN s.Resolved_Date IS NULL AND DATEDIFF(HOUR, s.Created_Date, GETDATE()) > s.Target_SLA_Hours THEN 1
                    ELSE 0 
                END AS Is_Breached,
                -- Dynamic financial penalty based on contractual tier and breach status
                CASE 
                    WHEN (s.Resolution_Time_Hours > s.Target_SLA_Hours OR (s.Resolved_Date IS NULL AND DATEDIFF(HOUR, s.Created_Date, GETDATE()) > s.Target_SLA_Hours)) THEN
                        CASE s.Priority
                            WHEN 'P1 - Critical' THEN 2500.00
                            WHEN 'P2 - High'     THEN 1000.00
                            WHEN 'P3 - Medium'   THEN 350.00
                            WHEN 'P4 - Low'      THEN 100.00
                            ELSE 0.00
                        END
                    ELSE 0.00
                END AS Penalty_Cost_GBP,
                -- Power Apps remediation flag
                CASE WHEN s.PowerApps_Remediated IN ('True', '1', 'Yes') THEN 1 ELSE 0 END AS PowerApps_Remediated,
                s.Remediation_Workflow_ID
            FROM stg.SLATickets_Raw s
            WHERE s.Ticket_ID IS NOT NULL
        ) AS source
        ON (target.Ticket_ID = source.Ticket_ID)
        WHEN MATCHED AND (
            target.Status <> source.Status
            OR target.Resolved_Date IS NULL AND source.Resolved_Date IS NOT NULL
            OR target.Resolution_Time_Hours <> source.Resolution_Time_Hours
        ) THEN
            UPDATE SET 
                target.Resolved_Date         = source.Resolved_Date,
                target.Priority              = source.Priority,
                target.Status                = source.Status,
                target.Resolution_Time_Hours = source.Resolution_Time_Hours,
                target.Is_Breached           = source.Is_Breached,
                target.Penalty_Cost_GBP      = source.Penalty_Cost_GBP,
                target.PowerApps_Remediated  = source.PowerApps_Remediated,
                target.Modified_At           = SYSDATETIME()
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                Ticket_ID,
                Created_Date,
                Resolved_Date,
                Priority,
                Status,
                Sector,
                Role,
                Cost_Center_Code,
                Site_Code,
                Employee_ID,
                Channel,
                Contract_Type,
                Resolution_Time_Hours,
                Target_SLA_Hours,
                Is_Breached,
                Penalty_Cost_GBP,
                PowerApps_Remediated,
                Remediation_Workflow_ID,
                Created_At,
                Modified_At
            )
            VALUES (
                source.Ticket_ID,
                source.Created_Date,
                source.Resolved_Date,
                source.Priority,
                source.Status,
                source.Sector,
                source.Role,
                source.Cost_Center_Code,
                source.Site_Code,
                source.Employee_ID,
                source.Channel,
                source.Contract_Type,
                source.Resolution_Time_Hours,
                source.Target_SLA_Hours,
                source.Is_Breached,
                source.Penalty_Cost_GBP,
                source.PowerApps_Remediated,
                source.Remediation_Workflow_ID,
                SYSDATETIME(),
                SYSDATETIME()
            )
        OUTPUT $action INTO #MergeActions;

        -- Tally inserted vs updated counts
        SELECT 
            @RowsInserted = COUNT(CASE WHEN ActionTaken = 'INSERT' THEN 1 END),
            @RowsUpdated  = COUNT(CASE WHEN ActionTaken = 'UPDATE' THEN 1 END)
        FROM #MergeActions;

        DROP TABLE #MergeActions;

        COMMIT TRANSACTION;

        -- Record successful execution
        INSERT INTO etl.ExecutionLog (
            BatchID, ProcedureName, StartTime, EndTime, ExecutionStatus,
            RowsInserted, RowsUpdated
        )
        VALUES (
            @BatchID, @ProcedureName, @StartTime, SYSDATETIME(), 'SUCCESS',
            @RowsInserted, @RowsUpdated
        );

        PRINT CONCAT('SUCCESS: [', @ProcedureName, '] inserted ', @RowsInserted, ' rows, updated ', @RowsUpdated, ' rows.');

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO etl.ExecutionLog (
            BatchID, ProcedureName, StartTime, EndTime, ExecutionStatus,
            ErrorMessage
        )
        VALUES (
            @BatchID, @ProcedureName, @StartTime, SYSDATETIME(), 'FAILED',
            @ErrorMessage
        );

        THROW 50001, @ErrorMessage, 1;
    END CATCH
END;
GO

-- ==============================================================================
-- 2. PROCEDURE: etl.sp_Load_Dim_Employees_SCD2
-- Description: Slowly Changing Dimension (SCD) Type 2 tracking for employee promotions,
--              organizational tier shifts, and sector re-alignments.
-- ==============================================================================
CREATE OR ALTER PROCEDURE etl.sp_Load_Dim_Employees_SCD2
    @BatchID NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartTime DATETIME2 = SYSDATETIME();
    DECLARE @ProcedureName NVARCHAR(100) = OBJECT_NAME(@@PROCID);
    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsUpdated INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);

    IF @BatchID IS NULL
        SET @BatchID = CONCAT('BATCH_', FORMAT(GETDATE(), 'yyyyMMdd_HHmmss'));

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Identify records where attributes changed (Tier, Role, Sector, etc.)
        -- Step 1: Expire old active records
        UPDATE target
        SET 
            target.Valid_To = DATEADD(DAY, -1, CAST(SYSDATETIME() AS DATE)),
            target.Is_Current = 0
        FROM dim.Employees target
        INNER JOIN stg.Employees_Raw source
            ON target.Employee_ID = source.Employee_ID
        WHERE target.Is_Current = 1
          AND (
              target.Role <> source.Role
              OR target.Tier_Hierarchy <> source.Tier_Hierarchy
              OR target.Sector <> source.Sector
              OR target.Security_Clearance <> source.Security_Clearance
          );

        SET @RowsUpdated = @@ROWCOUNT;

        -- Step 2: Insert new versions / new hires
        INSERT INTO dim.Employees (
            Employee_ID,
            Full_Name,
            Gender,
            Ethnicity,
            Sector,
            Role,
            Tier_Hierarchy,
            Hire_Date,
            Security_Clearance,
            Is_Veteran,
            Is_Apprentice,
            Valid_From,
            Valid_To,
            Is_Current
        )
        SELECT 
            s.Employee_ID,
            s.Full_Name,
            s.Gender,
            s.Ethnicity,
            s.Sector,
            s.Role,
            s.Tier_Hierarchy,
            s.Hire_Date,
            s.Security_Clearance,
            CASE WHEN s.Is_Veteran IN ('True', '1', 'Yes') THEN 1 ELSE 0 END,
            CASE WHEN s.Is_Apprentice IN ('True', '1', 'Yes') THEN 1 ELSE 0 END,
            CAST(SYSDATETIME() AS DATE) AS Valid_From,
            '9999-12-31' AS Valid_To,
            1 AS Is_Current
        FROM stg.Employees_Raw s
        LEFT JOIN dim.Employees d
            ON s.Employee_ID = d.Employee_ID
           AND d.Is_Current = 1
        WHERE d.Employee_SK IS NULL; -- Either brand new employee or just expired above

        SET @RowsInserted = @@ROWCOUNT;

        COMMIT TRANSACTION;

        -- Record successful execution
        INSERT INTO etl.ExecutionLog (
            BatchID, ProcedureName, StartTime, EndTime, ExecutionStatus,
            RowsInserted, RowsUpdated
        )
        VALUES (
            @BatchID, @ProcedureName, @StartTime, SYSDATETIME(), 'SUCCESS',
            @RowsInserted, @RowsUpdated
        );

        PRINT CONCAT('SUCCESS: [', @ProcedureName, '] inserted ', @RowsInserted, ' records, expired ', @RowsUpdated, ' historical records.');

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO etl.ExecutionLog (
            BatchID, ProcedureName, StartTime, EndTime, ExecutionStatus,
            ErrorMessage
        )
        VALUES (
            @BatchID, @ProcedureName, @StartTime, SYSDATETIME(), 'FAILED',
            @ErrorMessage
        );

        THROW 50002, @ErrorMessage, 1;
    END CATCH
END;
GO

-- ==============================================================================
-- 3. PROCEDURE: etl.sp_Run_Daily_Orchestration
-- Description: Master pipeline orchestration runner.
-- ==============================================================================
CREATE OR ALTER PROCEDURE etl.sp_Run_Daily_Orchestration
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MasterBatchID NVARCHAR(100) = CONCAT('ORCH_', FORMAT(GETDATE(), 'yyyyMMdd_HHmmss'));
    
    PRINT '=========================================================';
    PRINT CONCAT('STARTING SERCO ETL PIPELINE ORCHESTRATION: ', @MasterBatchID);
    PRINT '=========================================================';

    EXEC etl.sp_Load_Dim_Employees_SCD2 @BatchID = @MasterBatchID;
    EXEC etl.sp_Load_Fact_SLATickets @BatchID = @MasterBatchID;

    PRINT '=========================================================';
    PRINT 'PIPELINE ORCHESTRATION COMPLETED SUCCESSFULLY';
    PRINT '=========================================================';
END;
GO
