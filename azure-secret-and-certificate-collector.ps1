<#
===============================================================================================================
Required - PowerShell Version 5.1
===============================================================================================================
AUTHOR:  Murat Kaya a.k.a @mksecurity
DATE:    12/09/2024
VERSION: 1.0
===============================================================================================================
.SYNOPSIS
    This script retrieves application secrets and certificates from multiple environments such as Azure AD and Azure B2C.

.DESCRIPTION
    The script connects to both Azure AD (Entra) and Azure B2C directories, retrieves application secrets 
    and certificates, and exports the results in JSON format for easier processing.

.NOTES
    - Ensure the required Azure PowerShell modules are installed and updated.
    - Run this script in a secure and isolated environment with proper access permissions.
===============================================================================================================

DISCLAIMER:
This script is provided as-is without any warranties, expressed or implied. 
It is intended for educational purposes and internal use only. 
The script processes and generates critical detailed information about secrets and certificates. 
Improper use or modification of this script, or exposure of its output files, could lead to serious security risks. 
Ensure that all operations and outputs are protected and handled in a secure and safe environment.
Always validate the data and test in a safe environment before applying it to production systems. 
The author is not responsible for any damages or data loss resulting from the use of this script.

LICENSE:
This script is licensed under the GNU General Public License v3.0 (GPL-3.0).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty 
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. 
If not, see <https://www.gnu.org/licenses/>.

Author: Murat Kaya aka @mksecurity
Repository: https://github.com/murat-kaya/azure-secret-certificate-monitoring

#>

# Function to establish a connection to Azure AD or Azure B2C
function Connect-ToAzure {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantId
    )

    try {
        # Disconnect any existing Azure sessions for clean reauthentication
        Disconnect-AzAccount -Scope Process -ErrorAction SilentlyContinue
        Connect-AzAccount -TenantId $TenantId -Identity -Scope Process | Out-Null
        Write-Host "Successfully connected to tenant: $TenantId" -ForegroundColor Green
    } catch {
        Write-Error -Message "Failed to connect to tenant: $TenantId. Error: $($_.Exception.Message)"
        throw
    }
}

# Function to retrieve application credentials (secrets and certificates)
function Get-AppCredentials {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantName
    )

    $appDetails = @()
    $tenantContext = Get-AzContext
    $applications = Get-AzADApplication -DefaultProfile $tenantContext | Select-Object -Property AppId, Owner, DisplayName, PasswordCredentials, KeyCredentials

    foreach ($app in $applications) {
        # Process Password Credentials (Secrets)
        $secrets = @()
        foreach ($secret in $app.PasswordCredentials) {
            $secrets += @{
                Name          = $secret.DisplayName
                StartDateTime = $secret.StartDateTime.ToString("MM/dd/yyyy")
                EndDateTime   = $secret.EndDateTime.ToString("MM/dd/yyyy")
                RemainingDays = ($secret.EndDateTime - (Get-Date)).Days
            }
        }

        # Process Key Credentials (Certificates)
        $certificates = @()
        foreach ($certificate in $app.KeyCredentials) {
            $certificates += @{
                Name          = $certificate.DisplayName
                StartDateTime = $certificate.StartDateTime.ToString("MM/dd/yyyy")
                EndDateTime   = $certificate.EndDateTime.ToString("MM/dd/yyyy")
                RemainingDays = ($certificate.EndDateTime - (Get-Date)).Days
            }
        }

        # Collect application details
        $appDetails += @{
            TenantName    = $TenantName
            AppId         = $app.AppId
            Owner         = $app.Owner
            DisplayName   = $app.DisplayName
            Secrets       = $secrets
            Certificates  = $certificates
        }
    }
    return $appDetails
}

# Main script starts here
try {
    $allAppDetails = @()

    # Define the tenants to connect to
    $tenants = @(
        @{ TenantId = "test.onmicrosoft.com"; Name = "Azure AD" }
    )

    # Iterate through each tenant and gather application data
    foreach ($tenant in $tenants) {
        Write-Host "Processing tenant: $($tenant.Name) ($($tenant.TenantId))" -ForegroundColor Cyan
        Connect-ToAzure -TenantId $tenant.TenantId
        $tenantData = Get-AppCredentials -TenantName $tenant.Name
        $allAppDetails += $tenantData
    }

    # Convert collected data to JSON format for output
    $jsonOutput = $allAppDetails | ConvertTo-Json -Depth 3
    $outputFile = "AppCredentials.json"
    $jsonOutput | Set-Content -Path $outputFile -Encoding UTF8

    Write-Host "Data successfully exported to $outputFile" -ForegroundColor Green
} catch {
    Write-Error -Message "An error occurred during script execution: $($_.Exception.Message)"
} finally {
    Disconnect-AzAccount -Scope Process -ErrorAction SilentlyContinue
    Write-Host "Disconnected all Azure sessions." -ForegroundColor Yellow
}
