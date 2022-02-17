# NOTE: Requires DBATools, sqlserver module to be installed:
#install-module dbatools
#install-module Export-Excel
#TO DO:
#Test with Azure
#Test with SQL Logins as paramaters - create a connection string perhaps that can be reused
#Add a summary Process for all servers.

#Setup parameters:

param (
    [string]$InstanceNamesFile = ""
    ,[string]$SingleInstanceName = ""
    ,[string]$SqlLoginName = ""
    ,[string]$SqlLoginPassword = ""
    ,[bool]$AuthenticationPrompt = $false
        )

### FUNCTIONS:
######## TEST DATABASE CONNECTION
function Test-DatabaseConnection
{
    [CmdletBinding()]
    param(
           [Parameter(Mandatory = $true)]
           $DBCred,
           [Parameter(Mandatory = $true)]
           [String] $ServerInstance
         )

    If ($DBCred -eq ([System.Management.Automation.PSCredential]::Empty))
    {Test-DbaConnection -SqlInstance $ServerInstance}
    else
    {Test-DbaConnection -SqlInstance $ServerInstance -SqlCredential $DBCred}

}
######## Execute a Health Check query
function Execute-HealthCheckQueryFile
{
    [CmdletBinding()]
    param(
           [Parameter(Mandatory = $true)]
           $DBCred,
           [Parameter(Mandatory = $true)]
           [String] $SqlInstance,
           [Parameter(Mandatory = $true)]
           [String] $File,
           [String]$As = "DataRow"

         )

    If ($DBCred -eq ([System.Management.Automation.PSCredential]::Empty))
    {
    Invoke-DbaQuery -SqlInstance $SqlInstance -File $File -As $As -QueryTimeout 120
    }
    else
    {
    Invoke-DbaQuery -SqlInstance $SqlInstance -File $File -As $As -QueryTimeout 120 -SqlCredential $DBCred
    }

}
######## Execute a Standard SQL query
function Execute-HealthCheckQuery
{
    [CmdletBinding()]
    param(
           [Parameter(Mandatory = $true)]
           $DBCred,
           [Parameter(Mandatory = $true)]
           [String] $SqlInstance,
           [Parameter(Mandatory = $true)]
           [String] $Query,
           [String]$As = "DataRow"

         )

    If ($DBCred -eq ([System.Management.Automation.PSCredential]::Empty))
    {
    Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query -As $As -QueryTimeout 120
    }
    else
    {
    Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query -As $As -QueryTimeout 120 -SqlCredential $DBCred
    }

}


### MAIN SCRIPT #######
try {
    #Print date for reference:
    $date = Get-Date
    $date
    #SECTION: PRECHECKS:
    #Check pre-requiste modules installed
    if (Get-Module -ListAvailable -Name dbatools) {
        Write-Host "Module DBATools...Installed OK" -ForegroundColor Yellow
    } 
    else {
        throw "DBA Tools Module not installed.  Install this module before executing this script: https://dbatools.io/download/"
    }

    #Check only one instance parameter has been provided:
    If ($InstanceNamesFile -ne "" -and $SingleInstanceName -ne "")
    { throw "Only one Instance parameter should be provided." }

    #Check at least one instance has been provided:
    If ($InstanceNamesFile -eq "" -and $SingleInstanceName -eq "")
    { throw "At least one instance to check must be provided; Supply a value for one paramter: InstanceNamesFile or SingleInstanceName." }

    #A sql login should only be used when checking a single instance at a time:
    If ($InstanceNamesFile -ne "" -and $SingleInstanceName -eq "" -and $SqlLoginName -ne "")
    { throw "SQL Login parameter can only be used when checking a single instance. Do not use the InstanceNamesFile parameter." }

    #If the AuthenticationPrompt has been set to true then make sure sql login hasn't been provided also:
    If ($AuthenticationPrompt -eq $true -and $SqlLoginName -ne "")
    { throw "SQL Login parameter cannot be used when AuthenticationPrompt has been set to true." }

    #If SQL Login details have been provdied, but no password throw an error:
    If ($SqlLoginName -ne "" -and $SqlLoginPassword -eq "")
    { throw "No Password provdied when SQL Login has been specified" }
    
    #Create new Output folder if it doesn't exist.
    $OutputFolder = '.\Output'
     if (Test-Path -Path $OutputFolder) {
        Write-Host "Output directory available."
     } else {
        New-Item -Path . -Name "Output" -ItemType "directory"
    }
    If (-not(Test-Path $OutputFolder))
        { throw "Unable to create output folder $OutputFolder" }     

    #Check Instance Names File provided actually exists:
      if ($InstanceNamesFile -ne "") {
        If (-not(Test-Path $InstanceNamesFile))
        { throw "Instance source file not found. Please check the parameter entered for $InstanceNamesFile." }
        else {
            #Load each server into a variable
            $servers = Get-Content $InstanceNamesFile 
        }
    }
    #Get the Server passed in:
    elseif ($InstanceName -ne "") {
        $servers = $SingleInstanceName
    }

    #SECTION PRECHECKS: END ##################################################


    #Define the paths to the scripts to use:
    $Script_Summary_Server = $PSScriptRoot + "\Manifest\Script_Summary_Server.sql"
    $Script_Summary_Server_Uptime = $PSScriptRoot + "\Manifest\Script_Summary_Server_Uptime.sql"
    $Script_Summary_Server_CPURAM = $PSScriptRoot + "\Manifest\Script_Summary_Server_CPURAM.sql"
    $Script_Summary_Server_Storage = $PSScriptRoot + "\Manifest\Script_Summary_Server_Storage.sql"
    $Script_Summary_Server_FilePaths = $PSScriptRoot + "\Manifest\Script_Summary_Server_FilePaths.sql"
    $Script_Summary_Databases = $PSScriptRoot + "\Manifest\Script_Databases.sql"
    $Script_FileStats = $PSScriptRoot + "\Manifest\Script_FileStats.sql"
    $Script_spBlitz = $PSScriptRoot + "\Manifest\sp_Blitz.sql"
    $Script_AgentDetails = $PSScriptRoot + "\Manifest\Script_AgentJobs.sql"
    $Script_Waits = $PSScriptRoot + "\Manifest\Script_WaitStats.sql"
    $Script_BackupHistory = $PSScriptRoot + "\Manifest\Script_BackupHistoryDuration.sql"

    #Get the Excel Template File:
    $ExcelTemplate = $PSScriptRoot + "\Manifest\DiscoveryTemplate.xlsx"
    
    #Create a new PSCredential object is required:
    $Credential = $null
    if ($AuthenticationPrompt -eq $true)
    {
        $Credential = $host.ui.PromptForCredential("Need credentials", "Please enter your user name and password to connect to the SQL Instance", "", "")
    }

    if ($SqlLoginName -ne "")
    {        
        $PWord = ConvertTo-SecureString -String $SqlLoginPassword -AsPlainText -Force
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SqlLoginName, $PWord
    }
    
    #SECTION: RUN CHECKS AGAINST THE SERVERS
    Write-Host "Total Instances to Process: " $servers.Count  -ForegroundColor Green
    $processingCount = 0
    foreach ($instance in $servers) {
        $processingCount = $processingCount + 1
        "Querying Instance: " + $instance + " (" + $processingCount + " of " + $servers.Count + ")"

        #First, lets check the instance exists and we can connect.
        $ConnectionSuccess = $null
        if($Credential -eq $null) { $Credential = ([System.Management.Automation.PSCredential]::Empty)}
        $ConnectionSuccess = Test-DatabaseConnection -DBCred $Credential -ServerInstance $instance
        If ($ConnectionSuccess.ConnectSuccess -eq "true") 
        {
        Write-Host "   Connected Successfully."    -ForegroundColor Green        
        
        #If we can connect, then lets make sure we have SA permissions.
        Write-Host "   Checking for correct permissions..."
        $SysadminCheck = Execute-HealthCheckQuery -SqlInstance $instance -Query "select IS_SRVROLEMEMBER('sysadmin') as Access" -As SingleValue -DBCred $Credential

        #Get Server Edition - Azure instances will need different checks:
        $ServerEdition = Execute-HealthCheckQuery -SqlInstance $instance -Query "SELECT SERVERPROPERTY('EngineEdition') as Edition" -DBCred $Credential -As SingleValue
        if ($ServerEdition -eq '5' -or $ServerEdition -eq '6' -or $ServerEdition -eq '9' -or $ServerEdition -eq '11')
            {$IsAzure = $true}
        else
            {$IsAzure = $false}

        if($ServerEdition -eq '8')
            {$IsAzureMS = $true}
        else
            {$IsAzureMS = $false}

        if ($sysadmincheck -eq 1 -or $IsAzure -eq $true) ##Correct permissions so run the checks
        { 
            Write-Host "   Permissions - OK. Creating output file:" -ForegroundColor Green

            $InstanceShort = $instance -replace "\\", "-"
            $timestamp = $timestamp = (get-date).tostring("yyyyMMddHHmm")
            $OutputFile = $PSScriptRoot + "\Output\$InstanceShort-$timestamp.xlsx"
            Copy-Item -Path $ExcelTemplate -Destination $OutputFile

            #Get the Server Machine Name
            $MachineName = Execute-HealthCheckQuery -SqlInstance $instance -Query "SELECT SERVERPROPERTY('MachineName') as MachineName" -DBCred $Credential

            #TO DO:  RUN SCRIPTS BASED ON VERSION OF SQL SERVER - WHERE APPLICABLE.
            
            #Server Summary:
            Write-Host "      Collecting: Server Summary"
            Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_Summary_Server -As PSObjectArray -DBCred $Credential | Export-Excel -Path $OutputFile  -WorksheetName Summary -AutoSize -StartRow 1 -StartColumn 1 -TableName Summary -TableStyle Medium1
            
            if ($IsAzure -ne $true) #Skip for Azure SQL Type instances
            {
            Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_Summary_Server_Uptime -As PSObjectArray -DBCred $Credential | Export-Excel -Path $OutputFile  -WorksheetName Summary -AutoSize -StartRow 4 -StartColumn 1 -TableName Uptime -TableStyle Medium1
            Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_Summary_Server_CPURAM -As PSObjectArray -DBCred $Credential | Export-Excel -Path $OutputFile  -WorksheetName Summary -AutoSize -StartRow 7 -StartColumn 1 -TableName CPURAM -TableStyle Medium1
            Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_Summary_Server_Storage -As PSObjectArray -DBCred $Credential | Export-Excel -Path $OutputFile  -WorksheetName Summary -AutoSize -StartRow 11 -StartColumn 1 -TableName Storage -TableStyle Medium1
            Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_Summary_Server_FilePaths -As PSObjectArray -DBCred $Credential | Export-Excel -Path $OutputFile  -WorksheetName FilePaths -AutoSize -StartRow 1 -StartColumn 1 -TableName FilePaths -TableStyle Medium1

            Write-Host "      Collecting: Instance Health"
            Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_spBlitz -DBCred $Credential | Export-Excel -Path $OutputFile  -WorksheetName "Health Check" -AutoSize -StartRow 1 -StartColumn 1 -TableName HealthCheck -TableStyle Medium1
            
            Write-Host "      Collecting: Backup History"
            Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_BackupHistory -DBCred $Credential | Export-Excel -Path $OutputFile -WorksheetName "Backup History" -AutoSize -StartRow 1 -StartColumn 1 -TableName BackupHistory -TableStyle Medium1
            }
            else
            {
            #Azure Specific Queries: - Need to write these!
            }
                       

            Write-Host "      Collecting: Database Information"
            Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_Summary_Databases -DBCred $Credential | Export-Excel -Path $OutputFile -WorksheetName Databases -AutoSize -StartRow 1 -StartColumn 1 -TableName Databases -TableStyle Medium1

            Write-Host "      Collecting: Wait Stats"
            Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_Waits -As PSObjectArray -DBCred $Credential | Export-Excel -Path $OutputFile -WorksheetName Waits -AutoSize -StartRow 1 -StartColumn 1 -TableName WaitStats -TableStyle Medium1
            
                        
            if ($IsAzure) #Skip for Azure SQL Type instances
            {
                 Write-Host "      Skipping: File Stats - Azure SQL or Edge Instances"
                'Azure Instance - Data Not Collected' | Export-Excel -Path $OutputFile -WorksheetName FileStats -AutoSize -StartRow 1 -StartColumn 1 -TableName FileStats -TableStyle Medium1

                 Write-Host "      Skipping: Agent Jobs - Azure SQL or Edge Instances"
                'Azure Instance - Data Not Collected' | Export-Excel -Path $OutputFile -WorksheetName Jobs -AutoSize -StartRow 1 -StartColumn 1 -TableName Jobs -TableStyle Medium1

                Write-Host "      Skipping: Service Information - Azure SQL or Edge Instances"
                'Azure Instance - Data Not Collected' | Export-Excel -Path $OutputFile -WorksheetName Services -AutoSize -StartRow 1 -StartColumn 1 -TableName Services -TableStyle Medium1

                Write-Host "      Skipping: Backup History - Azure SQL or Edge Instances"
                'Azure Instance - Data Not Collected' | Export-Excel -Path $OutputFile -WorksheetName "Backup History" -AutoSize -StartRow 1 -StartColumn 1 -TableName BackupHistory -TableStyle Medium1
             
            }
            else 
            {
                Write-Host "      Collecting: File Stats"
                Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_FileStats -DBCred $Credential | Export-Excel -Path $OutputFile -WorksheetName FileStats -AutoSize -StartRow 1 -StartColumn 1 -TableName FileStats -TableStyle Medium1

                Write-Host "      Collecting: Agent Jobs"
                Execute-HealthCheckQueryFile -SqlInstance $instance -file $Script_AgentDetails -DBCred $Credential | Export-Excel -Path $OutputFile -WorksheetName Jobs -AutoSize -StartRow 1 -StartColumn 1 -TableName AgentJobs -TableStyle Medium1

                if ($IsAzureMS -ne $true)
                {
                Write-Host "      Collecting: Service Information" 
                get-service -name *sql* -ComputerName $MachineName.MachineName | SELECT name, Status, DisplayName, ServiceName, StartType | Export-Excel -Path $OutputFile  -WorksheetName Services -AutoSize -StartRow 1 -StartColumn 1 -TableName Services -TableStyle Medium1
                }
                              
            }          
                        
        
            Write-host "Querying Instance: $instance - Complete" -ForegroundColor Green
        }
        Else
        {
            #Dont have the correct permissions, so update the connectioncheck table
            Write-Host '       User does not have sysadmin permissions on the instance: $instance. Skipping all checks.' -ForegroundColor Red
            
         }
        }
        else {
            #Instances where connection failed:
            Write-host '       Connection Failed. Server: $instance' -ForegroundColor Red
            
           
        }

    }
    Write-Output 'Process Completed.' 
    
}

catch {
    Write-Output $PSItem
}




