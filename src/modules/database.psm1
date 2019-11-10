if ((Get-Module -ListAvailable | where-object {($_.Name -eq 'SqlServer') -and ($_.Version.Major -gt 20) } |Measure).Count -eq 1){ 
    # implementation of new sql modules migated into new location 
    Import-Module SqlServer -DisableNameChecking 
} 
else{ 
    # fallback for SQLPS  
    Import-Module SQLPS -DisableNameChecking 
}   	

function DetatchDatabases()
{
	param (
        [Parameter(Mandatory=$True)][string]$databaseFolderPath,
		[string]$nameprefix=""
    )
	
	begin
	{
		Write-Verbose "Detatching Databases"
	}
	process
	{
		Write-Verbose "- Checking folder: $databaseFolderPath"

		if(-Not(Test-Path $databaseFolderPath))
		{
			return
		}

		$dir = Get-ChildItem $databaseFolderPath -Recurse

		$mdfFiles = $dir | Where-Object {$_.Extension -eq ".mdf"}

		foreach($mdfFile in $mdfFiles)
		{
			$dbname = "$nameprefix$($mdfFile.BaseName.replace(".", "_"))"
			
			DetatchDatabase -dbname $dbname -Verbose
		}
	}
	end
	{
		Write-Verbose "Databases Detatched"
	}
}

function DetatchDatabase()
{
	param (
        [Parameter(Mandatory=$True)][string]$dbname
    )
	
	begin
	{
		Write-Verbose "Detatching Database: $dbname"
	}
	process
	{
		$query = "
IF DB_ID ('$dbname') IS NOT NULL
BEGIN
	ALTER DATABASE $dbname SET SINGLE_USER
	ALTER DATABASE $dbname SET OFFLINE
	EXEC sp_detach_db '$dbname', 'true'; 
END
";
	
		Invoke-Sqlcmd -query $query -serverinstance $serverinstance -verbose
	}
	end
	{
		Write-Verbose "Database Detatched"
	}
}

function AttachDatabases()
{
	param (
        [Parameter(Mandatory=$True)][string]$databaseFolderPath,
		[Parameter(Mandatory=$True)][string]$username,
		[Parameter(Mandatory=$True)][string]$password,
		[string]$nameprefix=""
    )
	
	begin
	{
		Write-Verbose "Attaching Databases"
	}
	process
	{
		AddLoginToServer -username $username -password $password -Verbose

		Write-Verbose "- Checking folder: $databaseFolderPath"

		$dir = Get-ChildItem $databaseFolderPath -Recurse

		$mdfFiles = $dir | Where-Object {$_.Extension -eq ".mdf"}

		foreach($mdfFile in $mdfFiles)
		{
			$dbname = "$nameprefix$($mdfFile.BaseName.replace(".", "_"))"
			$mdfpath = $mdfFile.FullName
			$ldfpath = $mdfpath -replace '.mdf', '.ldf' #this format is important to replace MDF and mdf

			AttachDatabase -dbname $dbname -mdfPath $mdfpath -ldfPath $ldfpath -Verbose

			AddUserToDatabase -dbname $dbname -username $username -rolename "db_owner" -Verbose
		}
	}
	end
	{
		Write-Verbose "Databases Attached"
	}
}

function AttachDatabase()
{
	param (
        [Parameter(Mandatory=$True)][string]$dbname,
		[Parameter(Mandatory=$True)][string]$mdfPath,
		[Parameter(Mandatory=$True)][string]$ldfPath,
		[string]$serverinstance="."
    )
	
	begin
	{
		Write-Verbose "Attaching Database: $dbname "
		Write-Verbose "- mdfPath: $mdfPath "
		Write-Verbose "- ldfPath: $ldfPath "
	}
	process
	{
		$query = "
IF DB_ID ('$dbname') IS NULL
	CREATE DATABASE $dbname 
		ON (FILENAME = '$mdfPath'), 
		(FILENAME = '$ldfPath') 
		FOR ATTACH;
";
	
		Invoke-Sqlcmd -query $query -serverinstance $serverinstance -verbose
	}
	end
	{
		Write-Verbose "Database Attached: $dbname "
	}
}

function AddLoginToServer
{
	param (
        [Parameter(Mandatory=$True)][string]$username,
		[Parameter(Mandatory=$True)][string]$password
    )

	begin
	{
		Write-Verbose "Add Login To Server: $username "
	}
	process
	{
		
		$query = "
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = '$username')
BEGIN
    CREATE LOGIN [$username] WITH PASSWORD = N'$password', CHECK_POLICY = OFF
END
"
		Invoke-Sqlcmd -query $query -serverinstance $serverinstance -verbose
	}
	end
	{
		Write-Verbose "Login Added "
	}
}

function AddUserToDatabase()
{
	param (
        [Parameter(Mandatory=$True)][string]$dbname,
		[Parameter(Mandatory=$True)][string]$username,
		[Parameter(Mandatory=$True)][string]$rolename
    )

	begin
	{
		Write-Verbose "Assign User Role: $dbname $username $rolename "
	}
	process
	{
		
		$query = "
USE $dbname
GO

IF DATABASE_PRINCIPAL_ID('$username') IS NULL
	CREATE USER $username

ALTER ROLE [$rolename] ADD MEMBER [$username]
"
		Invoke-Sqlcmd -query $query -serverinstance $serverinstance -verbose
	}
	end
	{
		Write-Verbose "Role Assigned "
	}
}

Export-ModuleMember DetatchDatabases, AttachDatabases