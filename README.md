# Sitecore Setup

Allows you to quickly spin up a sitecore instance based on a json file.

It can do the following:
- Install an instance of Sitecore
- Install sitecore modules
- Create IIS sites
- Create host file entries
- Add user to Performance Counters Group
- Apply permissions to folders
- Attach Databases
- Create required SQL users

## Process

1. Checkout your sitecore repo
1. Download the required Sitecore zip to c:\temp\sitecore\versions
1. Update settings.json with your environment settings
1. Open Powershell Console as an Administrator
1. Run install.ps1 (install-with-exm.ps1)

## Settings.json spec

### settings

| Object name   | Description                    |
| ------------- | ------------------------------ |
| `sitecore`      | Settings for sitecore and the required sites stored as a `sitecore` object|
| `sites`   | A collection of `iis-site` objects     |

    {
        "sitecore": { ... },
        "sites": { ... }
    }

### sitecore

| Object name   | Description                    | 
| ------------- | ------------------------------ | 
| `version` | The version of sitecore to use. It should match the name of the zip file (sans .zip) | 
| `license` | The full path to where the license.xml file can be found. | 
| `sitecoreVersionsFolder` | The path where all your sitecore zip files are stored |
| `databaseServer` | Database server name |
| `databasePrefix` | Appended to the start of the default sitecore database names. i.e. value of "Client_" becomes Client_Sitecore_Core | 
| `databaseLogin` | Database username. This user will be automatically created in the database |
| `databasePassword` | Database user password |
| `mongodbServer` | Mongodb server IP address for connection strings |
| `mongodbPrefix` | Appended to the start of the default sitecore database names i.e. valof of "Client_" becomes Client_Sitecore_tracking_live |
| `sites` | A collection of `sitecore-site` objects | 

    {
        "version": "Sitecore 8.2 rev. 170614",
        "license": "C:\\Projects\\client\\dep\\license.xml",
        "sitecoreVersionsFolder": "c:\\temp\\sitecore\\versions\\",
        "databaseServer": ".",
        "databasePrefix": "Client_",
        "databaseLogin": "loudandclear",
        "databasePassword": "loudandclear",
        "mongodbServer": "127.0.0.1",
		"mongodbPrefix": "Client_",
        "sites": { ... }
    }

### sitecore-site

| Object name   | Description                    | 
| ------------- | ------------------------------ |
| `sitename` | Used to map a sitecore site to an IIS site. __Must be the same as__ `iis-site.sitename` __!!__ | 
| `rootPath` | The path to the folder that will contain sitecores folder: data, database and website folders  | 
| `role` | Site role: `authoring` or `delivery`. For single instance sites use `authoring`  | 
| `modules` | A list of `sitecore-module` objects to install in this sitecore instance  |

    {
        "sitename": "Client-CM",
        "rootPath": "c:\\websites\\client.cm\\",
        "role": "authoring",
        "modules": { ... }
    }

### sitecore-module

| Object name   | Description                    | 
| ------------- | ------------------------------ | 
| `path` | The full path to the module to install | 
| `type` | Installation type: `sitecorePackage`, `zip`. __sitecorePackage__: installs using sitecores package installer. __zip__: installs by extracting and copying the file to sitecores website folder  |
| `prefunction` | Optional. Powershell function to call before installing the sitecore module. i.e. `InstallWFFMPre`, `InstallEXMPre` |
| `postaction` | Optional. Powershell function to call after installing the sitecore module. i.e. `InstallEXMPost` |

    {
        "path": "C:\\Projects\\funlab\\dep\\sitecore-packages\\301 Redirect Module-1.6.zip",
        "type": "sitecorePackage"
    },
    {
        "path": "C:\\Projects\\Client\\dep\\sitecore-packages\\EXM-3.4.2\\Email Experience Manager 3.4.2 rev. 170713.zip",
        "type": "sitecorePackage",
        "prefunction": "InstallEXMPre",
        "postfunction": "InstallEXMPost"
    }

### iis-site

| Object name   | Description                    | Sample                         |
| ------------- | ------------------------------ | ------------------------------ |
| `sitename` | Used for the site and app pool in IIS. __Must be the same as__ `sitecore-site.sitename` __!!__ | Client-CM | 
| `physicalpath` | Path that iis uses for the website. Will be `sitecore-site.rootPath` +  website | c:\\\\websites\\\\client.cm\\\\website\\\\ | 
| `addbindingstohosts` | `true` or `false`. When true, all items in the bindings collection will be added to the hosts file | |
| `bindings` | A collection of `iis-binding` to apply to the current site | |

    {
        "sitename": "Client-CM",
        "physicalpath": "c:\\websites\\client.cm\\website",
        "bindings": { ... }
    }

### iis-binding

| Object name   | Description                    | Sample                         |
| ------------- | ------------------------------ | ------------------------------ |
| `hostname` | Url for the site | client.cm.local |
| `port` | Port to bind to. Typcially 80 for http or 433 for https | 80 or 433 |
| `protocol` | Protocol for the binding. | http or https |

    {
        "hostname": "client.cm.local",
        "port": "80",
        "protocol": "http"
    }