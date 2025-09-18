<#
=========================================================================================================================
Required:
    Powershell Version 5.1 
Modules: 
    Microsoft.Graph.Users, Microsoft.Graph, Microsoft.Graph.Applications, Microsoft.Graph.Authentication, 
=========================================================================================================================
AUTHOR:  MKAYA
DATE:    12/09/2025
Version: 3.0
=========================================================================================================================
.SYNOPSIS
    This script retrieves Application secrets and certificates from multiple environments such as Azure AD and Azure B2C.
.DESCRIPTION
    The script will connect to both Azure AD (Entra) and Azure B2C directories, retrieve application secrets and certificates,
    and export the results in JSON format for easier processing.
#>

# Icons for states (red - expired, yellow - near expire, green - ok)
$iconGreen = "data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiB3aWR0aD0iMTYiIHZpZXdCb3g9IjAgMCAxNiAxNiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSI4IiBjeT0iOCIgcj0iOCIgZmlsbD0iI2QwZjQ4MyIvPjwvc3ZnPg=="
$iconYellow = "data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiB3aWR0aD0iMTYiIHZpZXdCb3g9IjAgMCAxNiAxNiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSI4IiBjeT0iOCIgcj0iOCIgZmlsbD0iI2ZmYjYwMCIvPjwvc3ZnPg=="
$iconRed = "data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiB3aWR0aD0iMTYiIHZpZXdCb3g9IjAgMCAxNiAxNiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSI4IiBjeT0iOCIgcj0iOCIgZmlsbD0iI2ZmMzMzMyIvPjwvc3ZnPg=="


# Function to connect to Azure AD or Azure B2C
function Connect-ToAzure {
    param (
        [string]$TenantId
    )
    try {
        #Write-Host "Connecting....: $TenantId"
       if (Get-MgContext) 
        {
            Disconnect-MgGraph
        }
        Connect-MgGraph -Identity -ContextScope Process
        #Write-Output "Connected to tenant: $TenantId"
    }
    catch {
        #Write-Output "Cannot be connected Graph $TenantId"
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Function to get applications and credentials
function Get-AppCredentials {
    param (
        [string]$TenantName
    )

    $objects = @()
    try {

        $apps = Get-MgApplication -All | Select-Object -Property Id, AppId, Owner, DisplayName, PasswordCredentials, KeyCredentials
        #Write-Output "Applications:" $apps.Count
    }
    catch {
        #Write-Output "Cannot query Get-MgApplication"
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    

    foreach ($app in $apps) {
        $owners = Get-MgApplicationOwnerAsUser -ApplicationId $app.Id
        $ownerNames = ($owners | ForEach-Object { $_.UserPrincipalName }) -join ", "

        $secrets = @()
        $hasExpired = $false
        $hasWarning = $false

        foreach ($secret in $app.PasswordCredentials) {
            $remainingDays = ($secret.EndDateTime - (Get-Date)).Days
            if ($remainingDays -lt 0) { $hasExpired = $true }
            elseif ($remainingDays -le 30) { $hasWarning = $true }

            $secrets += @{
                "Name"          = $secret.DisplayName
                "StartDateTime" = $secret.StartDateTime.ToString("MM/dd/yyyy")
                "EndDateTime"   = $secret.EndDateTime.ToString("MM/dd/yyyy")
                "RemainingDays" = $remainingDays
            }
        }

        $certificates = @()
        foreach ($certificate in $app.KeyCredentials) {
            $remainingDays = ($certificate.EndDateTime - (Get-Date)).Days
            if ($remainingDays -lt 0) { $hasExpired = $true }
            elseif ($remainingDays -le 30) { $hasWarning = $true }

            $certificates += @{
                "Name"          = $certificate.DisplayName
                "StartDateTime" = $certificate.StartDateTime.ToString("MM/dd/yyyy")
                "EndDateTime"   = $certificate.EndDateTime.ToString("MM/dd/yyyy")
                "RemainingDays" = $remainingDays
            }
        }

        # Filter out for only red and yellow states
        if (($hasExpired -or $hasWarning) -and ($secrets.Count -gt 0 -or $certificates.Count -gt 0)) {
            $objects += @{
                "TenantName"   = $TenantName
                "AppId"        = $app.AppId
                "Owners"       = $ownerNames
                "DisplayName"  = $app.DisplayName
                "Secrets"      = $secrets
                "Certificates" = $certificates
            }
        }

    }

  
    return $objects
}

# Main script starts here
$allObjects = @()

# Define the tenants to connect to
$tenants = @(
    @{ "TenantId" = "abc.onmicrosoft.com"; "Name" = "Azure AD ABC" }
)

# Loop through each tenant and gather the data
foreach ($tenant in $tenants) {
    Connect-ToAzure -TenantId $tenant.TenantId

    # Collect data from the current tenant
    $tenantObjects = Get-AppCredentials -TenantName $tenant.Name
    $allObjects += $tenantObjects

}

# Convert collected data to JSON and output
$jsonOutput = $allObjects | ConvertTo-Json -Depth 3

$reportObjects = $jsonOutput | ConvertFrom-Json

$htmlBody = @"
<html>
<head>
<style>
    body { font-family: Arial; Font-Size:12px }
    table { border-collapse: collapse; width: 100%; margin-bottom: 30px; Font-Size: 11px }
    th, td { border: 1px solid #000000ff; padding: 8px; text-align: left; }
    th { background-color: #a4a4a4ff; color: white; }
    .expired { background-color: #af342bff; color: white; } /* Red */
    .warning { background-color: #ffeb3b; color: black; } /* Yellow */
</style>
</head>
<body>
<h2>Application Credential Report</h2>
"@

foreach ($app in $reportObjects) {
        
    # Default icon color (green)
    $icon = $iconGreen

    # Expire Control
    $hasExpired = $false
    $hasWarning = $false

    foreach ($secret in $app.Secrets) {
        if ($secret.RemainingDays -lt 0) { $hasExpired = $true }
        elseif ($secret.RemainingDays -le 30) { $hasWarning = $true }
    }

    foreach ($cert in $app.Certificates) {
        if ($cert.RemainingDays -lt 0) { $hasExpired = $true }
        elseif ($cert.RemainingDays -le 30) { $hasWarning = $true }
    }

    # Change color with states.
    if ($hasExpired) {
        $icon = $iconRed
    }
    elseif ($hasWarning) {
        $icon = $iconYellow
    }

    # Update HTML icons.
    $htmlBody += "<h3><img src='$icon' alt='status' style='width:16px;height:16px;vertical-align:middle;margin-right:5px;' /> $($app.DisplayName) - ($($app.TenantName))</h3><h4><b>Owners:</b>  ($($app.Owners))</h4>"

    $htmlBody += "<p><b>AppId:</b> $($app.AppId)</p>"

    # Secret Tables
    if ($app.Secrets.Count -gt 0) {
        $htmlBody += "<b>Secrets</b><table><tr><th>Name</th><th>Start Date</th><th>End Date</th><th>Remaining Days</th></tr>"
        foreach ($secret in $app.Secrets) {
            $class = ""
            if ($secret.RemainingDays -lt 0) {
                $class = "expired"
            }
            elseif ($secret.RemainingDays -le 30) {
                $class = "warning"
            }

            $htmlBody += "<tr class='$class'><td>$($secret.Name)</td><td>$($secret.StartDateTime)</td><td>$($secret.EndDateTime)</td><td>$($secret.RemainingDays)</td></tr>"
        }
        $htmlBody += "</table>"
    }

    # Certificate Tables
    if ($app.Certificates.Count -gt 0) {
        $htmlBody += "<b>Certificates</b><table><tr><th>Name</th><th>Start Date</th><th>End Date</th><th>Remaining Days</th></tr>"
        foreach ($cert in $app.Certificates) {
            $class = ""
            if ($cert.RemainingDays -lt 0) {
                $class = "expired"
            }
            elseif ($cert.RemainingDays -le 30) {
                $class = "warning"
            }

            $htmlBody += "<tr class='$class'><td>$($cert.Name)</td><td>$($cert.StartDateTime)</td><td>$($cert.EndDateTime)</td><td>$($cert.RemainingDays)</td></tr>"
        }
        $htmlBody += "</table>"
    }

    $htmlBody += "<hr>"
}

$htmlBody += "</body></html>"

Write-Output $htmlBody

Write-Output $jsonOutput
