# 🔐 Azure AD Password Expiry Report Automation

This PowerShell script connects to Microsoft Graph and generates a report on Azure Active Directory users’ password expiration status. It helps IT admins proactively identify expiring or expired passwords, spot accounts with "password never expires", and automate notification or remediation workflows.

---

## 🚀 Features

- Retrieves all Azure AD users via Microsoft Graph
- Calculates days remaining until password expiration
- Filters by:
  - Passwords that never expire
  - Soon-to-expire passwords
  - Recently changed passwords
  - Enabled accounts only
  - Licensed users only
- Outputs results to CSV
- Fully scriptable for automation (e.g., via Task Scheduler, Azure Automation)

---

## 🛠️ Prerequisites

- PowerShell 7+
- Microsoft Graph PowerShell SDK  
  Install using:
  ```powershell
  Install-Module Microsoft.Graph -Scope CurrentUser

