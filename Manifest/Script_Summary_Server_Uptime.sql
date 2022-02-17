SELECT
    CAST(create_date AS VARCHAR(100)) as "Last Startup",
    CAST(DATEDIFF(hh,create_date,getdate())/24. as numeric (23,2)) AS "Days Uptime"
FROM    sys.databases
WHERE   database_id = 2;