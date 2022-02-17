DECLARE @ServerType INT;

SELECT @ServerType = CAST(SERVERPROPERTY('EngineEdition') AS INT);

IF @ServerType <> 5
BEGIN
    IF EXISTS (SELECT * FROM sys.dm_os_performance_counters)
        SELECT TOP 1
               COALESCE(
                           CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(100)),
                           LEFT(object_name, (CHARINDEX(':', object_name) - 1))
                       ) AS "Machine Name",
               ISNULL(CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(100)), '(default instance)') AS "Instance Name",
               CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100)) AS "Product Version",
               CASE
                   WHEN CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(2)) IN ( '10', '11', '12', '13' )
                        AND SERVERPROPERTY('EngineEdition') NOT IN ( 5, 6, 8 ) THEN
                       CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(100))
                   ELSE
                       ''
               END AS "Patch Level",
               CAST(SERVERPROPERTY('Edition') AS VARCHAR(100)) AS Edition,
               CAST(SERVERPROPERTY('IsClustered') AS VARCHAR(100)) AS IsClustered,
               CAST(COALESCE(SERVERPROPERTY('IsHadrEnabled'), 0) AS VARCHAR(100)) AS "AlwaysOn Enabled",
               '' AS Warning,
               CAST(SERVERPROPERTY('Collation') AS VARCHAR(100)) AS Collation
        FROM sys.dm_os_performance_counters;
    ELSE
        SELECT TOP 1
               (CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(100))) AS "Machine Name",
               ISNULL(CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(100)), '(default instance)') AS "Instance Name",
               CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100)) AS "Product Version",
               CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(100)) AS "Patch LEVEL",
               CAST(SERVERPROPERTY('Edition') AS VARCHAR(100)) AS Edition,
               CAST(SERVERPROPERTY('IsClustered') AS VARCHAR(100)) AS IsClustered,
               CAST(COALESCE(SERVERPROPERTY('IsHadrEnabled'), 0) AS VARCHAR(100)) AS "AlwaysOn Enabled",
               CAST(SERVERPROPERTY('Collation') AS VARCHAR(100)) AS Collation,
               'WARNING - No records found in sys.dm_os_performance_counters' AS Warning;
END;
ELSE
BEGIN
    IF EXISTS (SELECT * FROM sys.dm_os_performance_counters)
        SELECT TOP 1
               COALESCE(
                           CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(100)),
                           LEFT(object_name, (CHARINDEX(':', object_name) - 1))
                       ) AS "Machine Name",
               'Azure SQL' AS "Instance Name",
               CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100)) AS "Product Version",
               CASE
                   WHEN CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(2)) IN ( '10', '11', '12', '13' )
                        AND SERVERPROPERTY('EngineEdition') NOT IN ( 5, 6, 8 ) THEN
                       CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(100))
                   ELSE
                       ''
               END AS "Patch Level",
               CAST(SERVERPROPERTY('Edition') AS VARCHAR(100)) AS Edition,
               CAST(SERVERPROPERTY('IsClustered') AS VARCHAR(100)) AS IsClustered,
               CAST(COALESCE(SERVERPROPERTY('IsHadrEnabled'), 0) AS VARCHAR(100)) AS "AlwaysOn Enabled",
               '' AS Warning,
               CAST(SERVERPROPERTY('Collation') AS VARCHAR(100)) AS Collation
        FROM sys.dm_os_performance_counters;
END;