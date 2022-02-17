-- SCRIPT TO RETRIEVE DETAILS OF ALL VOLUMES AND MOUNT POINTS DEFINED ON THE SERVER. 


-- First check and set the xp_cmdshell configuration value.
-- We'll reset this back after we've used it.

DECLARE @chkCMDShell AS SQL_VARIANT;
SELECT @chkCMDShell = value
FROM sys.configurations
WHERE name = 'xp_cmdshell';
IF @chkCMDShell = 0
BEGIN
    EXEC sp_configure N'show advanced Options', 1;
    RECONFIGURE;
    EXEC sp_configure 'xp_cmdshell', 1;
    RECONFIGURE;
END;


-- Then run a powershell command to get all the volumne information from each disk/mount point.
DECLARE @svrName VARCHAR(255);
DECLARE @sql VARCHAR(400);
--by default it will take the current server name, we can the set the server name as well
SET @svrName = @@SERVERNAME;
SET @sql
    = 'Powershell.exe "Get-WmiObject -ComputerName ' + CAST(SERVERPROPERTY('MachineName') AS VARCHAR(100))
      + ' -Class Win32_Volume -Filter ''DriveType = 3'' | select name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"';

--creating a temporary table
CREATE TABLE #output
(
    line VARCHAR(250)
);
--inserting disk name, total space and free space value in to temporary table
INSERT #output
EXEC xp_cmdshell @sql;

--script to retrieve the values in MB from PS Script output
SELECT 
       RTRIM(LTRIM(SUBSTRING(line, 1, CHARINDEX('|', line) - 1))) AS "Drive Name",
       ROUND(
                CAST(RTRIM(LTRIM(SUBSTRING(
                                              line,
                                              CHARINDEX('|', line) + 1,
                                              (CHARINDEX('%', line) - 1) - CHARINDEX('|', line)
                                          )
                                )
                          ) AS FLOAT),
                0
            ) AS 'Capacity(MB)',
       ROUND(
                CAST(RTRIM(LTRIM(SUBSTRING(
                                              line,
                                              CHARINDEX('%', line) + 1,
                                              (CHARINDEX('*', line) - 1) - CHARINDEX('%', line)
                                          )
                                )
                          ) AS FLOAT),
                0
            ) AS 'Freespace(MB)'
FROM #output
WHERE line LIKE '[A-Z][:]%'
ORDER BY "Drive Name";

--script to drop the temporary table
DROP TABLE #output;

-- Reset the xp_cmdshell value back to what it was.
IF @chkCMDShell = 0
BEGIN
    EXEC sp_configure N'show advanced Options', 1;
    RECONFIGURE;
    EXEC sp_configure 'xp_cmdshell', 0;
    RECONFIGURE;
    EXEC sp_configure N'show advanced Options', 0;
    RECONFIGURE;
END;

