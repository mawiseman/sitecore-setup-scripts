Import-Module WebAdministration

function ConfigureIIS
{
    param (
        [Parameter(Mandatory=$True)][PSCustomObject]$site
    )

    begin 
    {
        Write-Verbose "Creating Site: $($site.sitename)"
    }
    process
    {
		# App Pool

		$sitePath = "IIS:\AppPools\$($site.sitename)"

        if(Test-Path $sitePath)
		{
			Remove-WebAppPool $site.sitename
		}
		New-WebAppPool $site.sitename
		Set-ItemProperty -Path $sitePath -name "processModel" -value @{identitytype="ApplicationPoolIdentity"}
		
		# Website

		if(Get-Website -Name $site.sitename)
		{
			Remove-Website -Name $site.sitename
		}
		New-Website -Name $site.sitename -HostHeader $site.sitename -PhysicalPath $site.physicalpath -ApplicationPool $site.sitename
		
		# Bindings
		
		New-Host -ip 127.0.0.1 -hostname $site.sitename -Verbose
		
		ForEach ($binding in $site.bindings)
        {
			New-WebBinding -Name $site.sitename -IP "*" -Port $binding.port -HostHeader $binding.hostname -protocol $binding.protocol
		
			if($site.addbindingstohosts -eq "true")
			{
				New-Host -ip 127.0.0.1 -hostname $binding.hostname -Verbose
			}
		}
		
		Start-WebSite -Name $site.sitename
    }
    end
    {
       Write-Verbose "Created site: $($site.sitename)"
    }
}

function New-Host() 
{
	param (
        [parameter(Mandatory=$True)][string]$ip="127.0.0.1",
        [parameter(Mandatory=$True)][string]$hostname="localhost",
		[string]$filename="C:\Windows\System32\drivers\etc\hosts"
    )
	
	begin
	{
		
	}
	process
	{
		Remove-Host -hostname $hostname  -Verbose
		$ip + "`t`t" + $hostname | Out-File -encoding ASCII -append $filename
	}
	end
	{
	}
}

function Remove-Host() 
{
	param (
        [parameter(Mandatory=$True)][string]$hostname="localhost",
		[string]$filename="C:\Windows\System32\drivers\etc\hosts"
    )
	
	begin
	{
	}
	process
	{
	
		$c = Get-Content $filename
		$newLines = @()
		
		foreach ($line in $c) {
			$bits = [regex]::Split($line, "\t+")
			if ($bits.count -eq 2) {
				if ($bits[1] -ne $hostname) {
					$newLines += $line
				}
			} else {
				$newLines += $line
			}
		}
		
		# Write file
		Clear-Content $filename
		foreach ($line in $newLines) {
			$line | Out-File -encoding ASCII -append $filename
		}
	}
	end
	{
	}
}

Export-ModuleMember ConfigureIIS