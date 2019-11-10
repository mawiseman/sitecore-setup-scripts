
function InstallEXMPre()
{
	param (
		[Parameter(Mandatory=$True)][object]$settings,
		[Parameter(Mandatory=$True)][string]$sitecorePath
	)

	begin 
	{
		Write-Verbose "Install EXM Pre"
	}

	process 
	{
		AddDefaultEXMConnectionStrings `
			-sitecorePath $sitecorePath `
			-Verbose

		UpdateConnectionStrings `
			-serverInstance $settings.sitecore.databaseServer `
			-sitecorePath $sitecorePath `
			-nameprefix $settings.sitecore.databasePrefix `
			-username $settings.sitecore.databaseLogin `
			-password $settings.sitecore.databasePassword `
			-mongodbServer $settings.sitecore.mongodbServer `
			-mongodbPrefix $settings.sitecore.mongodbPrefix `
			-Verbose
	}

	end 
	{
		Write-Verbose "EXM Pre Complete"
	}
}

function InstallEXMPost()
{
	param (
		[Parameter(Mandatory=$True)][object]$settings,
		[Parameter(Mandatory=$True)][string]$sitecorePath
	)

	begin 
	{
		Write-Verbose "Install EXM Post"
	}

	process 
	{
		# Move the EXM database to the the Databases folder

		Move-Item "$sitecorePath\Website\temp\ExM" "$sitecorePath\Databases" -Force

		# Attache the ECM Databases

		AttachDatabases -nameprefix $settings.sitecore.databasePrefix `
			-databaseFolderPath "$sitecorePath\Databases\ExM" `
			-username $settings.sitecore.databaseLogin `
			-password $settings.sitecore.databasePassword `
			-Verbose
	}

	end 
	{
		Write-Verbose "EXM Post Complete"
	}
}

function AddDefaultEXMConnectionStrings()
{
	param (
		[Parameter(Mandatory=$True)][string]$sitecorePath
    )

	begin
	{
		Write-Verbose "Add Default EXM Connection Strings"
	}
	process
	{
		# Currenlty built for EXM 3.4

		# add db connections strings

		$connectionStringPath = "$sitecorePath\website\app_config\connectionstrings.config"

		# open connection strings file

		$connectionstrings = New-Object System.Xml.XmlDocument
		$connectionstrings.Load($connectionStringPath)

		# master

		$connection = $connectionstrings.connectionStrings.add[0].clone()
		$connection.name = "exm.master"
		$connection.connectionString = "user id=user;password=password;Data Source=(server);Database=Sitecore.Exm"
		$connectionstrings.DocumentElement.AppendChild($connection)

		# web

		$connection = $connectionstrings.connectionStrings.add[0].clone()
		$connection.name = "exm.web"
		$connection.connectionString = "user id=user;password=password;Data Source=(server);Database=Sitecore.Exm_Web"
		$connectionstrings.DocumentElement.AppendChild($connection)

		# EXM.CryptographicKey

		$connection = $connectionstrings.connectionStrings.add[0].clone()
		$connection.name = "EXM.CryptographicKey"
		$connection.connectionString = "0000000000000000000000000000000000000000000000000000000000000000"
		$connectionstrings.DocumentElement.AppendChild($connection)

		# EXM.AuthenticationKey

		$connection = $connectionstrings.connectionStrings.add[0].clone()
		$connection.name = "EXM.AuthenticationKey"
		$connection.connectionString = "0000000000000000000000000000000000000000000000000000000000000000"
		$connectionstrings.DocumentElement.AppendChild($connection)

		# save

		$connectionstrings.Save($connectionStringPath)
	}
	end
	{
		Write-Verbose "Default EXM Connection Strings Added"
	}
}

Export-ModuleMember InstallEXMPre, InstallEXMPost
