<#PSScriptInfo

.VERSION 0.2

.GUID 607fb605-4905-4e2f-849f-0dee2fe9415d

.AUTHOR Kilian Arjona

.COMPANYNAME

.COPYRIGHT (c) 2019-2020 Kilian Arjona. All rights reserved.

.TAGS NVIDIA GRID license server

.LICENSEURI https://opensource.org/licenses/MIT

.PROJECTURI https://github.com/karjona/Get-NVIDIAVirtualGPULicenses

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

0.2 - 23-Mar-2020
-- Group data from different licenses if they use the same Feature Name

0.1 - 21-Jan-2020
-- First release. Yay!
#>

<#
.SYNOPSIS
Parse nvidialsadmin output to easily obtain consumed and total NVIDIA GRID licenses in the environment.

.DESCRIPTION
The Get-NVIDIAVirtualGPULicenses script returns a JSON with license usage data (feature name, licenses consumed,
license available and licenses total) of a NVIDIA Virtual GPU License Server.

This script must be run on the NVIDIA License Server and requires a working installation of nvidialsadmin.bat: a
command line utility that is installed by default with the license server.

This script does not query the license server directly. It parses the results returned by the nvidialsadmin utility
so you can later easily process or upload this information to a third-party monitoring tool.

.PARAMETER NVIDIALSAdminFullPath
Specifies the full path to a working installation of nvidialsadmin.bat.

.EXAMPLE
Get-NVIDIAVirtualGPULicenses.ps1 -NVIDIALSAdminFullPath 'C:\Program Files\NVIDIA\License Server\enterprise'

Example 1: Get the license usage data
Returns the usage data reported by the local license server in string format. nvidialsadmin.bat is located in the
specified path.
#>


param(
[Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0, HelpMessage='Enter the full path to the' +
' nvidialsadmin.bat command line utility. For default installations you can use' +
' C:\Program Files\NVIDIA\License Server\enterprise')]
[String]
$NVIDIALSAdminFullPath
)

#$output = @'
#=======================================================================================
#Feature ID      Feature Name           Feature Version   Feature Count Used/Available
#=======================================================================================
#1               Quadro-Virtual-DWS            5.0                  0/60
#2               GRID-Virtual-Apps             3.0                  17/43
#=======================================================================================
#
#'@

#$output = @'
#=======================================================================================
#Feature ID      Feature Name           Feature Version   Feature Count Used/Available
#=======================================================================================
#3               GRID-Virtual-Apps             3.0                  10/340
#4               GRID-Virtual-Apps             3.0                  0/135
#5               GRID-Virtual-PC               2.0                  1/134
#=======================================================================================
#
#'@

Set-Location -Path $NVIDIALSAdminFullPath
$output = & '.\nvidialsadmin.bat' -licenses -verbose | Out-String

$regex = "(?m)^(?<id>\d+)(?:\s{2,25})(?<feature>.+?)(?:\s{2,45})(?<version>.+?)(?:\s{2,45})(?<used>\d+)(?:\/)(?<available>\d+)"
$results = Select-String -Pattern $regex -InputObject $output -AllMatches

$JSON = @()
$ParsedResults = @{}

foreach ($result in $results.Matches) {
  $Name = $result.Groups["feature"].Value
  $Used = [Int16]$result.Groups["used"].Value
  $Available = [Int16]$result.Groups["available"].Value
  $Total = [Int16]$result.Groups["available"].Value + [Int16]$result.Groups["used"].Value

  if ($ParsedResults.Contains($Name)) {
    $ParsedResults.$Name.Used += $Used
    $ParsedResults.$Name.Available += $Available
    $ParsedResults.$Name.Total += $Total
  } else {
    $r = @{}
    $r[$Name] = @{
      "Name" = $Name
      "Used" = $Used
      "Available" = $Available
      "Total" = $Total
    }
    $ParsedResults += $r
  }
}

foreach ($pr in $ParsedResults.Values) {
  $JSON += @{
    "Name" = $pr.Name
    "Total" = $pr.Total
    "Available" = $pr.Available
    "Used" = $pr.Used
  }
}

ConvertTo-Json -InputObject $JSON
