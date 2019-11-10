# Import Modules

Import-Module $PSScriptRoot\modules\sitecore.psm1
Import-Module $PSScriptRoot\modules\sitecore-wffm.psm1
Import-Module $PSScriptRoot\modules\sitecore-exm.psm1
Import-Module $PSScriptRoot\modules\database.psm1
Import-Module $PSScriptRoot\modules\iis.psm1
Import-Module $PSScriptRoot\modules\menu.psm1
Import-Module $PSScriptRoot\modules\write-ascii\write-ascii.psd1

Write-Ascii "Setup Sitecore" -ForegroundColor Green

# Load Settings

$settingsFiles = [ordered]@{}
Get-ChildItem | Where-Object {$_.extension -eq ".json" } | Sort-Object Name | ForEach { $settingsFiles.Add( $_.fullname, $_.Name) }
$settingsFiles.Add("cancel", "cancel")

$selectedSettingFile = ShowMenu "Select Settings File" $settingsFiles

if($selectedSettingFile -eq "cancel") {
	Write-Ascii "Bye Bye" -ForegroundColor Red
	return
}

$settings = (Get-Content $selectedSettingFile | ConvertFrom-Json)

# Get Sitecore

Write-Host "Get Sitecore: $($settings.sitecore.version)" 

ExtractSitecore -sitecoreVersion $settings.sitecore.version -sitecoreVersionsFolder $settings.sitecore.sitecoreVersionsFolder -Verbose

# Detaching databases

Write-Host "Detaching databases" 

ForEach ($sitecoreSite in $settings.sitecore.sites)
{
	if($sitecoreSite.role -eq "authoring")
	{
		DetatchDatabases -nameprefix $settings.sitecore.databasePrefix  -databaseFolderPath "$($sitecoreSite.rootPath)\Databases"  -Verbose
	}
}

# Create Sites

Write-Host "Create Sites"

ForEach ($sitecoreSite in $settings.sitecore.sites)
{
	Write-Host "Create Site: $($sitecoreSite.sitename)" 

	$iisSite = $settings.sites | Where-Object sitename -eq $sitecoreSite.sitename

	InstallSitecore -sitecoreVersion $settings.sitecore.version -sitecorePath $sitecoreSite.rootPath -sitecoreVersionsFolder $settings.sitecore.sitecoreVersionsFolder -Verbose
	UpdateDataFolder -sitecorePath $sitecoreSite.rootPath -Verbose
	InstallLicense -sitecorePath $sitecoreSite.rootPath -licensePath $settings.sitecore.license  -Verbose

	ConfigureIIS -site $iisSite -Verbose
}

# Install Databases

Write-Host "Install Databases"

ForEach($sitecoreSite in $settings.sitecore.sites)
{
	if($sitecoreSite.role -eq "authoring")
	{
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

ForEach($sitecoreSite in $settings.sitecore.sites)
{
	AddAppPoolToLocalUserGroups -appPoolIdentity "iis apppool\$($sitecoreSite.sitename)" -Verbose
	ApplyFolderPermissions -sitecorePath $sitecoreSite.rootPath -appPoolIdentity "iis apppool\$($sitecoreSite.sitename)" -Verbose
}

# Starting Sitecore

ForEach($sitecoreSite in $settings.sitecore.sites)
{
	$iisSite = $settings.sites | Where-Object sitename -eq $sitecoreSite.sitename
	$iisSiteUrl = "http://$($sitecoreSite.sitename)"

	if($sitecoreSite.role -eq "authoring")
	{
		Start-Sitecore $iisSiteUrl -Verbose
	}
}

# Install Modules

Write-Host "Install Modules"

ForEach ($sitecoreSite in $settings.sitecore.sites)
{
	$iisSite = $settings.sites | Where-Object sitename -eq $sitecoreSite.sitename
	$iisSiteUrl = "$($iisSite.bindings[0].protocol)://$($iisSite.bindings[0].hostname)"

	if($sitecoreSite.role -eq "authoring")
	{
		InstallPackageHelpers -sitecorePath $sitecoreSite.rootPath -Verbose
	}

	ForEach($module in $sitecoreSite.modules)
	{
		if(![bool]$module.prefunction -eq "")
		{
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

		if(![bool]$module.postfunction -eq "")
		{
			& $module.postfunction  `
				-settings $settings `
				-sitecorePath $sitecoreSite.rootPath `
				-Verbose
		}
	}
}

Write-Ascii "Sitecore!" -ForegroundColor Green


