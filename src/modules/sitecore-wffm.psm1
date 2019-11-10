
function InstallWFFMPost()
{
	param (
		[Parameter(Mandatory=$True)][object]$settings,
		[Parameter(Mandatory=$True)][string]$sitecorePath
	)

	begin 
	{
		Write-Verbose "Install WFFM Post"
	}

	process 
	{
		Invoke-Sqlcmd -ServerInstance $settings.sitecore.databaseServer `
			-Username $settings.sitecore.databaseLogin `
			-Password $settings.sitecore.databasePassword `
			-Database "$($settings.sitecore.databasePrefix)Sitecore_Analytics" `
			-InputFile "$sitecorePath\\Website\\Data\\WFFM_Analytics.sql"
	}

	end 
	{
		Write-Verbose "WFFM Post Complete"
	}
}

Export-ModuleMember InstallWFFMPost
