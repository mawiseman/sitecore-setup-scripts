# Import Modules

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

InstallSitecore -sitecoreSettingFile $selectedSettingFile

Write-Ascii "Sitecore!" -ForegroundColor Green


