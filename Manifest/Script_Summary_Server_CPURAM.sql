DECLARE @StringToExecute NVARCHAR(4000)
/* Sys info, SQL 2012 and higher */
IF EXISTS ( SELECT  *
			FROM    sys.all_objects o
					INNER JOIN sys.all_columns c ON o.object_id = c.object_id
			WHERE   o.name = 'dm_os_sys_info'
					AND c.name = 'physical_memory_kb' )
	BEGIN
		SET @StringToExecute = '
        SELECT
            cpu_count as "CPU Count",
            CAST(ROUND((physical_memory_kb / 1024.0 / 1024), 1) AS INT) as "Physical Memory GB",
			ROUND(CAST([value] AS int),1)/1000 as "SQL Assigned Memory GB"

        FROM sys.dm_os_sys_info, sys.configurations
		WHERE sys.configurations.name = ''max server memory (MB)'''
		;
		EXECUTE(@StringToExecute);
	END
/* Sys info, SQL 2008R2 and prior */
ELSE IF EXISTS ( SELECT  *
			FROM    sys.all_objects o
					INNER JOIN sys.all_columns c ON o.object_id = c.object_id
			WHERE   o.name = 'dm_os_sys_info'
					AND c.name = 'physical_memory_in_bytes' )
    BEGIN
		    SET @StringToExecute = '
            SELECT
                cpu_count as "CPU Count",
                CAST(ROUND((physical_memory_in_bytes / 1024.0 / 1024.0 / 1024.0 ), 1) AS INT) as "Physical Memory GB",
			ROUND(CAST([value] AS int),1)/1000 as "SQL Assigned Memory GB"
            FROM sys.dm_os_sys_info, sys.configurations
		WHERE sys.configurations.name = ''max server memory (MB)''';
			    EXECUTE(@StringToExecute);
    END
ELSE IF SERVERPROPERTY('EngineEdition') IN (5, 6, 7)
    BEGIN
    SELECT COUNT(*) AS "CPU Count", 'Unknown' AS "Physical Memory GB"
      FROM sys.dm_os_schedulers 
      WHERE status = 'VISIBLE ONLINE'
    END
ELSE
    SELECT 'Unknown' AS "CPU Count", 'Unknown' AS "Physical Memory GB";