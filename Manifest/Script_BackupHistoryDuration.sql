DECLARE @dbname sysname;
SET @dbname = NULL; --set this to be whatever dbname you want
SELECT bup.database_name AS [Database],
       bup.user_name AS [User],
       bup.server_name AS [Server],
       bup.backup_start_date AS [Backup Started],
       bup.backup_finish_date AS [Backup Finished],
       CAST((CAST(DATEDIFF(s, bup.backup_start_date, bup.backup_finish_date) AS INT)) / 3600 AS VARCHAR) + ' hours, '
       + CAST((CAST(DATEDIFF(s, bup.backup_start_date, bup.backup_finish_date) AS INT)) / 60 AS VARCHAR) + ' minutes, '
       + CAST((CAST(DATEDIFF(s, bup.backup_start_date, bup.backup_finish_date) AS INT)) % 60 AS VARCHAR) + ' seconds' AS [Total Time]
FROM msdb.dbo.backupset bup
WHERE bup.backup_set_id IN
      (
          SELECT MAX(backup_set_id)
          FROM msdb.dbo.backupset
          WHERE database_name = ISNULL(@dbname, database_name) --if no dbname, then return all
                AND type = 'D' --only interested in the time of last full backup
          GROUP BY database_name
      )
UNION
SELECT [name],
       NULL,
       NULL,
       NULL,
       NULL,
       'No recent backup'
FROM sys.databases
WHERE [name] NOT IN
      (
          SELECT database_name
          FROM msdb.dbo.backupset
          WHERE type = 'D'
          GROUP BY database_name
      )
ORDER BY database_name;