'''
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


# For generating "data.json" you can use powershell script thar provided in this repo or write your own as you want.

P.S: 
You can use the JSON file generated with PowerShell directly in Azure LogicApps by performing the mapping there
instead of using the script below, integrating it into your automation workflow.
Similarly, you can directly utilize these scripts in LogicApps for automation purposes.


# EXAMPLE OUTPUT_TABLE
+--------------------------------------+------------+--------------------------------------------------------------------------------------+-------------+--------+----------+---------+
|                AppId                 | TenantName |                                     Application                                      |     Type    | Active | Expiring | Expired |
+--------------------------------------+------------+--------------------------------------------------------------------------------------+-------------+--------+----------+---------+
| c12315df-7bb4-44ea-a123-10493df3496b |  Azure EN  |                                ToolServiceApplication                                |    Secret   |   1    |    0     |    0    |
| 13a7224c-1fca-3c2e-8bfe-a5a621e123fb |  Azure EN  |                                      appsetest                                       |    Secret   |   1    |    0     |    2    |
+--------------------------------------+------------+--------------------------------------------------------------------------------------+-------------+--------+----------+---------+

# EXAMPLE DAYS REMAINING TABLE 
Certificates and secrets that will expire in the last 30 days:

+--------------------------------------+-------------------------------+--------+---------------+----------------+
|                AppId                 |          DisplayName          |  Type  |      Name     | Days Remaining |
+--------------------------------------+-------------------------------+--------+---------------+----------------+
| a1b4d46e-1219-3ac8-daa5-7cc057082de4 |        exampleformtest        | Secret |      None     |       25       |
| 02123274-36a3-4a18-a2c9-375a456cd225 | ExampleENTDashTableServiceDev | Secret | GovDashSecret |       4        |
| 1236a5ae-bea9-1236-a029-123eac016451 |        SampleApiExtGate       | Secret |    ewsecret   |       9        |
+--------------------------------------+-------------------------------+--------+---------------+----------------+


'''

import json
from datetime import datetime
from prettytable import PrettyTable
from pathlib import Path


# Constants
DAYS_THRESHOLD = 30
DATA_FILE = "data.json"
OUTPUT_TABLE_FILE = "main_output_table.txt"
DETAILED_OUTPUT_FILE = "detailed_output.json"
FILTERED_OUTPUT_FILE = "filtered_output.json"
EXPIRING_SOON_FILE = "expiring_table.txt"

# Load JSON data
def load_data(file_path):
    try:
        with open(file_path, 'r') as file:
            return json.load(file)
    except FileNotFoundError:
        print(f"Error: {file_path} not found.")
        return []
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON: {e}")
        return []

# Write to file
def write_to_file(file_path, content):
    with open(file_path, 'w') as file:
        file.write(content)

# Analyze expiry dates
def categorize_items(items, today):
    active, expiring_soon, expired = [], [], []
    for item in items:
        name = item.get("Name", "Unknown")
        end_date_str = item.get("EndDateTime", "Unknown")

        try:
            end_date = datetime.strptime(end_date_str, "%m/%d/%Y")
            days_remaining = (end_date - today).days

            if days_remaining < 0:
                expired.append(name)
            elif days_remaining <= DAYS_THRESHOLD:
                expiring_soon.append(name)
            else:
                active.append(name)
        except ValueError:
            expired.append(name)  # Treat invalid dates as expired

    return active, expiring_soon, expired

# Process application data
def process_applications(data, today):
    detailed_output = []
    filtered_output = []
    summary_table = PrettyTable(["AppId", "TenantName", "Application", "Type", "Active", "Expiring", "Expired"])
    expiring_soon_table = PrettyTable(["AppId", "DisplayName", "Type", "Name", "Days Remaining"])

    for app in data:
        app_id = app.get("AppId", "Unknown")
        tenant_name = app.get("TenantName", "Unknown")
        display_name = app.get("DisplayName", "Unknown")

        secrets = app.get("Secrets", [])
        certificates = app.get("Certificates", [])

        # Categorize secrets and certificates
        active_secrets, expiring_soon_secrets, expired_secrets = categorize_items(secrets, today)
        active_certificates, expiring_soon_certificates, expired_certificates = categorize_items(certificates, today)

        # Add rows to summary table
        if secrets:
            summary_table.add_row([app_id, tenant_name, display_name, "Secret", len(active_secrets), len(expiring_soon_secrets), len(expired_secrets)])
        if certificates:
            summary_table.add_row([app_id, tenant_name, display_name, "Certificate", len(active_certificates), len(expiring_soon_certificates), len(expired_certificates)])

        # Build detailed output
        detailed_entry = {
            "AppId": app_id,
            "TenantName": tenant_name,
            "DisplayName": display_name,
            "Secrets": {
                "Active": active_secrets,
                "ExpiringSoon": expiring_soon_secrets,
                "Expired": expired_secrets
            },
            "Certificates": {
                "Active": active_certificates,
                "ExpiringSoon": expiring_soon_certificates,
                "Expired": expired_certificates
            }
        }
        detailed_output.append(detailed_entry)

        # Build filtered output (Active = 1, Expiring = 1)
        if len(active_secrets) == 1 and len(expiring_soon_secrets) == 1:
            filtered_output.append({"Type": "Secret", **detailed_entry})
        if len(active_certificates) == 1 and len(expiring_soon_certificates) == 1:
            filtered_output.append({"Type": "Certificate", **detailed_entry})

        # Add expiring soon details to the expiring soon table
        for secret in secrets:
            name = secret.get("Name", "Unknown")
            end_date_str = secret.get("EndDateTime", "Unknown")
            try:
                end_date = datetime.strptime(end_date_str, "%m/%d/%Y")
                days_remaining = (end_date - today).days
                if 0 <= days_remaining <= DAYS_THRESHOLD:
                    expiring_soon_table.add_row([app_id, display_name, "Secret", name, days_remaining])
            except ValueError:
                continue

        for cert in certificates:
            name = cert.get("Name", "Unknown")
            end_date_str = cert.get("EndDateTime", "Unknown")
            try:
                end_date = datetime.strptime(end_date_str, "%m/%d/%Y")
                days_remaining = (end_date - today).days
                if 0 <= days_remaining <= DAYS_THRESHOLD:
                    expiring_soon_table.add_row([app_id, display_name, "Certificate", name, days_remaining])
            except ValueError:
                continue

    return summary_table, detailed_output, filtered_output, expiring_soon_table

# Main execution
def main():
    today = datetime.now()
    data = load_data(DATA_FILE)

    if not data:
        return

    summary_table, detailed_output, filtered_output, expiring_soon_table = process_applications(data, today)

    # Write outputs
    write_to_file(OUTPUT_TABLE_FILE, summary_table.get_string())
    write_to_file(DETAILED_OUTPUT_FILE, json.dumps(detailed_output, indent=4))
    write_to_file(FILTERED_OUTPUT_FILE, json.dumps(filtered_output, indent=4))
    write_to_file(EXPIRING_SOON_FILE, expiring_soon_table.get_string())

    # Print summary to console
    print("\nCertificates and secrets expiring in the next 30 days:")
    print(expiring_soon_table)

if __name__ == "__main__":
    main()
