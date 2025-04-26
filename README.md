# Description

Provide list of Windows services information from freshly installed Windows operating systems.
Also provide a simple ps1 script for comparison.

# Code to extract the list of Windows services

```ps1
Get-CimInstance -ClassName Win32_Service |
Select-Object Name, DisplayName, StartMode, State, PathName, Description, StartName, ServiceType |
Export-Csv -Path .\services<version_here>.csv -NoTypeInformation
```

# How to use?

Launch Powershell and first set the execution policy as so:

```ps1
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Run the `compare-services.ps1` scripts between two CVEs

```ps1
.\compare-services.ps1 -BaselineCsvPath .\services2025_full.csv -ComparisonCsvPath .\service2022_full.csv -OutputFolder .\
```
