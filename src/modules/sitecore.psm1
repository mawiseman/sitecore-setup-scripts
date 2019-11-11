
Import-Module $PSScriptRoot\sitecore-wffm.psm1
Import-Module $PSScriptRoot\sitecore-exm.psm1
Import-Module $PSScriptRoot\database.psm1
Import-Module $PSScriptRoot\iis.psm1

$AGENTPATH = "\website\sitecore\shell\sim-agent\"
$INSTALLPACKAGEURL = "/sitecore/shell/sim-agent/InstallPackage.aspx"

function ExtractSitecore() {
	param (
		[Parameter(Mandatory = $True)][string]$sitecoreVersion,
		[string]$sitecoreVersionsFolder = "C:\temp\sitecore\versions\"
	)
	
	begin {
		Write-Verbose "Extracting Sitecore"
	}
	process {
		$extractDestination = "$sitecoreVersionsFolder$sitecoreVersion";
		$sitecoreZipPath = "$($extractDestination).zip";
		
		if (-Not (Test-Path -Path $sitecoreZipPath)) {
			Write-Warning "---------------------------------------------------------------"
			Write-Warning "Sitecore was not found in $sitecoreVersionsFolder"
			Write-Warning ""
			Write-Warning "Download '$sitecoreVersion.zip' from:"
			Write-Warning "- Google Drive: Team Drives > Development > Sitecore"
			Write-Warning "- FTP: ftp.sitecore.loudandclear.info"
			Write-Warning ""
			Write-Warning "Save it to: $sitecoreVersionsFolder"
			Write-Warning "---------------------------------------------------------------"
			
			throw [System.IO.FileNotFoundException] "$sitecoreZipPath not found."
		}

		if (Test-Path -Path $extractDestination ) {
			Write-Verbose "- Sitecore already extracted: $extractDestination"
		}
		else {
			# extract to temp folder to prevent situation when extraction process is interupted
			# and after retrying script it shows 'Sitecore already extracted' and uses incomplete
			# set of files.

			$timestamp = (Get-Date).Ticks
			$temp = "$sitecoreVersionsFolder\..\$timestamp"

			Expand-Archive $sitecoreZipPath -DestinationPath "$temp"

			# since extraction succeded, move extracted folder from temp to destination
			Move-Item -Path "$temp\$sitecoreVersion" -Destination $sitecoreVersionsFolder

			# cleanup
			Remove-Item -Path "$temp" -Recurse -Force

			Write-Verbose "Sitecore extracted to: $extractDestination"
		}
	}
	end {
		Write-Verbose "Extracted Sitecore"
	}
}

function CopySitecore() {
	param (
		[Parameter(Mandatory = $True)][string]$sitecoreVersion,
		[Parameter(Mandatory = $True)][string]$sitecorePath,
		[string]$sitecoreVersionsFolder = "C:\temp\sitecore\versions\"
	)
	
	begin {
		Write-Verbose "Installing Sitecore"
	}
	process {
		# Install sitecore files

		$sourcePath = "$sitecoreVersionsFolder$sitecoreVersion"

		Write-Verbose "Copying files..."
		Write-Verbose "- Source Path $sourcePath"
		Write-Verbose "- Target Path $sitecorePath"
		
		# Ensure full path exists
		
		New-Item -ItemType Directory -Force -Path $sitecorePath

		# Copy Siteocre files

		Copy-Item $sourcePath\* $sitecorePath -Recurse -Force
	}
	end {
		Write-Verbose "Sitecore Installed"
	}
}

Function InstallLicense() {
	param (
		[Parameter(Mandatory = $True)][string]$sitecorePath,
		[Parameter(Mandatory = $True)][string]$licensePath
	)
	
	begin {
		Write-Verbose "Installing Sitecore License"
	}
	process {
		Copy-Item $licensePath $sitecorePath\Data -Recurse -Force
	}
	end {
		Write-Verbose "Sitecore License installed"
	}
}

Function UpdateDataFolder() {
	param (
		[Parameter(Mandatory = $True)][string]$sitecorePath
	)
	
	begin {
		Write-Verbose "Updating Data folder"
	}
	process {
		$datafolderConfigPath = "$sitecorePath\website\app_config\include\DataFolder.config.example"

		# update data path
		(Get-Content $datafolderConfigPath).replace('/data', $($sitecorePath + "/data")) | Set-Content $datafolderConfigPath

		# rename the file
		Move-Item $datafolderConfigPath $datafolderConfigPath.Replace("DataFolder.config.example", "DataFolder.config") -Force
	}
	end {
		Write-Verbose "Data folder updated"
	}
}

function UpdateConnectionStrings() {
	param (
		[Parameter(Mandatory = $True)][string]$namePrefix,
		[Parameter(Mandatory = $True)][string]$username,
		[Parameter(Mandatory = $True)][string]$password,
		[Parameter(Mandatory = $True)][string]$sitecorePath,
		[Parameter(Mandatory = $True)][string]$mongodbPrefix,
		[string]$serverinstance = ".",
		[string]$mongodbServer = "localhost"		
	)
	
	begin {
		Write-Verbose "Updating connection strings"
	}
	process {
		# open connection strings file
		$connectionStringPath = "$sitecorePath\website\app_config\connectionstrings.config"

		# update sql server
		(Get-Content $connectionStringPath).replace('(server)', $serverinstance) | Set-Content $connectionStringPath

		# update database names with the prefix
		(Get-Content $connectionStringPath).replace('Database=Sitecore_', "Database=$($namePrefix)Sitecore_") | Set-Content $connectionStringPath

		# update usernames
		(Get-Content $connectionStringPath).replace('user id=user;', "user id=$username;") | Set-Content $connectionStringPath

		# update passwords
		(Get-Content $connectionStringPath).replace('password=password;', "password=$password;") | Set-Content $connectionStringPath

		# update mongo tables
		(Get-Content $connectionStringPath).replace('mongodb://localhost/', "mongodb://$mongoDbServer/$mongodbPrefix") | Set-Content $connectionStringPath
	}
	end {
		Write-Verbose "Connection strings updated"
	}
}

function AddAppPoolToLocalUserGroups() {
	param (
		[Parameter(Mandatory = $True)][string]$appPoolIdentity
	)
	begin {
		Write-Verbose "Adding appPoolIdentity: '$appPoolIdentity' to Local User Groups"
	}
	process {
		$localUserGroups = "Performance Log Users", "Performance Monitor Users"
	
		ForEach ($localUserGroup in $localUserGroups) {
			Remove-LocalGroupMember -Group $localUserGroup -Member "$appPoolIdentity"  -ErrorAction SilentlyContinue
			Add-LocalGroupMember -Group $localUserGroup -Member "$appPoolIdentity"
		}
	}
	end {
		Write-Verbose "appPoolIdentity added to Local User Groups"
	}
}

function ApplyFolderPermissions() {
	param (
		[Parameter(Mandatory = $True)][string]$sitecorePath,
		[Parameter(Mandatory = $True)][string]$appPoolIdentity
	)
	begin {
		Write-Verbose "Adding permissions for: '$appPoolIdentity' to: $sitecorePath"
	}
	process {
		$acl = Get-Acl "$sitecorePath"
		$accessRule = New-Object  system.security.accesscontrol.filesystemaccessrule("$appPoolIdentity", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
		$acl.SetAccessRule($accessRule)
		
		Set-Acl "$sitecorePath" $acl
	}
	end {
		Write-Verbose "Permissions applied"
	}
}

function Start-Sitecore() {
	param (
		[Parameter(Mandatory = $True)][string]$url
	)

	begin {
		Write-Verbose "Starting Sitecore: $url"
	}
	process {
		# This will throw an exception if something went wrong
		# We need to set the result to something so as not to render it in the console

		$req = Invoke-WebRequest -URI $url
	}
	end {
		Write-Verbose "Sitecore Started"
	}
}

function InstallPackageHelpers() {
	param (
		[Parameter(Mandatory = $True)][string]$sitecorePath
	)

	begin {
		Write-Verbose "Installing Sitecore Package Helpers"
	}
	process {
		$agentPath = "$sitecorePath\$AGENTPATH"

		Copy-Item $PSScriptRoot\sitecore-helpers\* (New-Item "$agentPath" -Type container -Force) -Recurse -Force
	}
	end {
		Write-Verbose "Sitecore Package Helpers Installed"
	}
}

function Start-Sleep($activity, $status, $seconds) {
	$doneDT = (Get-Date).AddSeconds($seconds)

	while ($doneDT -gt (Get-Date)) {
		$secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
		$percent = ($seconds - $secondsLeft) / $seconds * 100

		Write-Progress -Activity $activity -Status $status -SecondsRemaining $secondsLeft -PercentComplete $percent

		[System.Threading.Thread]::Sleep(500)
	}

	Write-Progress -Activity $activity -Status $status -SecondsRemaining 0 -Completed
}

function InstallPackage {
	param (
		[Parameter(Mandatory = $True)][string]$sitecoreUrl,
		[Parameter(Mandatory = $True)][string]$sitecorePath,
		[Parameter(Mandatory = $True)][object]$module
	)
	begin {
		Write-Verbose "Installing Package $($module.path)"
	}
	process {
		if ($module.type -eq "sitecorePackage") {
			Copy-Item $module.path "$sitecorePath\data\packages\" -Force

			$filename = Split-Path $module.path -leaf

			$url = $sitecoreUrl + $INSTALLPACKAGEURL + "?fileName=$filename"

			# We use 'Start-Process' here instead of Invoke-WebRequest because
			# - it is an easy way for it to run async so we can show percieved progress

			Start-Process $url

			# poll the install

			$agentPath = "$sitecorePath\$AGENTPATH"
			$simStatusPath = "$sitecorePath\website\temp\sim.status"
			$inprogress = $true;

			do {
				if (Test-Path $simStatusPath) {
					Start-Sleep "Installing Package" $filename 5

					$status = (Get-Content $simStatusPath | ConvertFrom-Json)
					
					Write-Verbose "Checking status: $($status.packagename), $($status.status)"

					$inprogress = $status.status -eq "installing"
				}
				else {
					Start-Sleep "Waiting for start" $filename 5

					Write-Verbose "Waiting for start"
				}

			} while ($inprogress)

			Remove-Item $simStatusPath
		}

		if ($module.type -eq "zip") {
			Expand-Archive $module.path -DestinationPath $sitecorePath\website -Force
		}
	}
	end {
		Write-Verbose "Package Installed"
	}
}

function InstallSitecore() {
	param (
		[Parameter(Mandatory = $True)][string]$sitecoreSettingFile
	)
	begin {
		Write-Verbose "Installing Sitecore using $sitecoreSettingFile"
	}
	process {
		$settings = (Get-Content $sitecoreSettingFile | ConvertFrom-Json)

		# Get Sitecore

		Write-Host "Get Sitecore: $($settings.sitecore.version)" 

		ExtractSitecore -sitecoreVersion $settings.sitecore.version -sitecoreVersionsFolder $settings.sitecore.sitecoreVersionsFolder -Verbose

		# Detaching databases

		Write-Host "Detaching databases" 

		ForEach ($sitecoreSite in $settings.sitecore.sites) {
			if ($sitecoreSite.role -eq "authoring") {
				DetatchDatabases -nameprefix $settings.sitecore.databasePrefix  -databaseFolderPath "$($sitecoreSite.rootPath)\Databases"  -Verbose
			}
		}

		# Create Sites

		Write-Host "Create Sites"

		ForEach ($sitecoreSite in $settings.sitecore.sites) {
			Write-Host "Create Site: $($sitecoreSite.sitename)" 

			$iisSite = $settings.sites | Where-Object sitename -eq $sitecoreSite.sitename

			CopySitecore -sitecoreVersion $settings.sitecore.version -sitecorePath $sitecoreSite.rootPath -sitecoreVersionsFolder $settings.sitecore.sitecoreVersionsFolder -Verbose
			UpdateDataFolder -sitecorePath $sitecoreSite.rootPath -Verbose
			InstallLicense -sitecorePath $sitecoreSite.rootPath -licensePath $settings.sitecore.license  -Verbose

			ConfigureIIS -site $iisSite -Verbose
		}

		# Install Databases

		Write-Host "Install Databases"

		ForEach ($sitecoreSite in $settings.sitecore.sites) {
			if ($sitecoreSite.role -eq "authoring") {
				AttachDatabases -nameprefix $settings.sitecore.databasePrefix  -databaseFolderPath "$($sitecoreSite.rootPath)\Databases" -username $settings.sitecore.databaseLogin -password $settings.sitecore.databasePassword -Verbose
			}

			UpdateConnectionStrings `
				-serverInstance $settings.sitecore.databaseServer `
				-sitecorePath $sitecoreSite.rootPath `
				-nameprefix $settings.sitecore.databasePrefix `
				-username $settings.sitecore.databaseLogin `
				-password $settings.sitecore.databasePassword `
				-mongodbServer $settings.sitecore.mongodbServer `
				-mongodbPrefix $settings.sitecore.mongodbPrefix `
				-Verbose
		}

		# User Permissions

		ForEach ($sitecoreSite in $settings.sitecore.sites) {
			AddAppPoolToLocalUserGroups -appPoolIdentity "iis apppool\$($sitecoreSite.sitename)" -Verbose
			ApplyFolderPermissions -sitecorePath $sitecoreSite.rootPath -appPoolIdentity "iis apppool\$($sitecoreSite.sitename)" -Verbose
		}

		# Starting Sitecore

		ForEach ($sitecoreSite in $settings.sitecore.sites) {
			$iisSite = $settings.sites | Where-Object sitename -eq $sitecoreSite.sitename
			$iisSiteUrl = "http://$($sitecoreSite.sitename)"

			if ($sitecoreSite.role -eq "authoring") {
				Start-Sitecore $iisSiteUrl -Verbose
			}
		}

		# Install Modules

		Write-Host "Install Modules"

		ForEach ($sitecoreSite in $settings.sitecore.sites) {
			$iisSite = $settings.sites | Where-Object sitename -eq $sitecoreSite.sitename
			$iisSiteUrl = "$($iisSite.bindings[0].protocol)://$($iisSite.bindings[0].hostname)"

			if ($sitecoreSite.role -eq "authoring") {
				InstallPackageHelpers -sitecorePath $sitecoreSite.rootPath -Verbose
			}

			ForEach ($module in $sitecoreSite.modules) {
				if (![bool]$module.prefunction -eq "") {
					& $module.prefunction `
						-settings $settings `
						-sitecorePath $sitecoreSite.rootPath `
						-Verbose
				}

				InstallPackage `
					-sitecoreUrl $iisSiteUrl `
					-sitecorePath $sitecoreSite.rootPath `
					-module $module `
					-Verbose

				if (![bool]$module.postfunction -eq "") {
					& $module.postfunction  `
						-settings $settings `
						-sitecorePath $sitecoreSite.rootPath `
						-Verbose
				}
			}
		}
	}
	end {
		Write-Verbose "Sitecore Installed"
	}
}

Export-ModuleMember InstallSitecore
