# Application Secrets and Certificates Manager

This project retrieves and analyzes secrets and certificates from Azure AD and Azure B2C applications. The collected data is formatted and exported into JSON files and tabular output for better insights.

## Features

- **Multi-Tenant Support**: Retrieve secrets and certificates from Azure AD and Azure B2C directories.
- **Detailed Analysis**: Classify secrets and certificates into active, expiring soon, or expired.
- **Export Options**: Generate structured JSON and formatted text output.
- **Automation-Friendly**: JSON output can integrate directly with Azure Logic Apps for automation.

## Requirements

- **PowerShell Version**: 5.1 or higher
- **Azure CLI**: Installed and configured
- **JSON File Parsing**: Python 3.x with the `prettytable` library

## Installation

### PowerShell Script

1. Clone the repository:
   ```bash
   git clone https://github.com/murat-kaya/azure-secret-certificate-monitoring.git
   cd azure-secret-certificate-monitoring

2. Update the tenant information in the PowerShell script:
  > [!IMPORTANT]
  > You should update this field with your own tenant information. The name can be anything you want...
  ```
  $tenants = @(
      @{ "TenantId" = "your-tenant-id"; "Name" = "Your Tenant Name" }
  )
  ```

3. Run the script:
  ```bash
  .\azure-secret-and-certificate-collector.ps1
  ```

### Python Script

1. Install required Python libraries:
  ```bash
  pip install prettytable
  ```

2. Execute the Python script:
  ```bash
  python azure-secret-certificate-remaining-days-to-expire.py
  ```
  
## Usage
### PowerShell Script
The PowerShell script retrieves secrets and certificates for each tenant and generates a JSON file as output:
* Output: ``` AppCredentials.json ```

### Python Script
The Python script processes the JSON file from PowerShell to generate:

* Detailed Analysis: ``` detailed_output.json ```
* Filtered Results: ``` filtered_output.json ```
* Tabular Summary: ``` main_output_table.txt, expiring_table.txt ```

### Integration with Azure Logic Apps
The JSON output can be directly used in Azure Logic Apps for:

* Mapping fields instead of using python script to extract information from json and send direct mail or alert to whom concern.
* Automating alerts or actions based on filters (remaining days etc.)
  
Example: Automate email notifications for secrets expiring in 30 days.

## Examples
### JSON Output Example

```json
[
    {
        "TenantName": "Azure ENT",
        "AppId": "a124e46e-e1ac-3a18-bee5-7cc1238312b",
        "DisplayName": "ExampleApp",
        "Secrets": {
            "Active": ["Secret1", "Secret2"],
            "ExpiringSoon": ["Secret3"],
            "Expired": []
        },
        "Certificates": {
            "Active": ["Cert1"],
            "ExpiringSoon": ["Cert2"],
            "Expired": []
        }
    }
]
```

### Expiring Soon Table Example

```diff
+--------------------------------------+-------------------+--------+---------+----------------+
|               AppId                  |   DisplayName     |  Type  |   Name  | Days Remaining |
+--------------------------------------+-------------------+--------+---------+----------------+
| a312346e-eb99-4ac8-1235-744057083deb | ExampleApp        | Secret | Secret3 |  7             |
| f123274d-36a3-4218-a123-3754f123cef4 | AnotherApp        | Secret | Secret1 |  3             |
+--------------------------------------+-------------------+--------+---------+----------------+
```

### License
This project is licensed under the GPLv3 License - see the [LICENSE](https://github.com/murat-kaya/azure-secret-certificate-monitoring/blob/main/LICENSE) file for details.


### Disclaimer
**Warning**: This script generates highly sensitive information, including secrets and certificates. 
Ensure all files and outputs are stored in a secure environment with proper access controls to prevent unauthorized access.
